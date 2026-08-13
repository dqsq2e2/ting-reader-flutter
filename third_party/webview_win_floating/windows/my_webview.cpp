#include "my_webview.h"

#include <functional>
#include <algorithm>
#include <iostream>
#include <map>
#include <utility> // std::pair
#include <regex>
#include <cwchar>
#include <cwctype>

#include <windows.h>
#include <WebView2.h>

#include <wrl.h>
#include <wil/com.h>

using namespace Microsoft::WRL;

std::string utf8_encode(const std::wstring& wstr)
{
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

std::string Utf8FromUtf16(LPWSTR wstr) {
    DWORD dBufSize = WideCharToMultiByte(CP_UTF8, 0, wstr, -1, NULL, 0, NULL, FALSE);
    char* dBuf = new char[dBufSize];
    int nRet = WideCharToMultiByte(CP_UTF8, 0, wstr, -1, dBuf, dBufSize, NULL, FALSE);
    if (nRet <= 0) return "";
    std::string result = std::string(dBuf);
    delete[]dBuf;
    return result;
}

// --------------------------------------------------------------------------

class MyWebViewImpl : public MyWebView
{
public:
    MyWebViewImpl(HWND hWnd,
        MyWebViewCreateParams params,
        PCWSTR pwUserDataFolder,
        PCWSTR pwProfileName);

    virtual ~MyWebViewImpl() override;

	void setHasNavigationDecision(bool hasNavigationDecision);
    void allowNavigationRequest(int requestId, bool isAllowed);

    HRESULT loadUrl(PCWSTR url);
    HRESULT setRequestHeaders(
        LPCWSTR origin,
        const std::map<std::wstring, std::wstring>& headers);
    HRESULT loadHtmlString(PCWSTR html);
    HRESULT runJavascript(PCWSTR javaScriptString, bool ignoreResult, std::function<void(std::string)> callback);

    HRESULT addScriptChannelByName(
        LPCWSTR channelName, std::function<void(HRESULT)> callback);
    void removeScriptChannelByName(LPCWSTR channelName);

    void enableJavascript(bool bEnable);

    void enableStatusBar(bool bEnable);

    void enableIsZoomControl(bool bEnable);

    HRESULT setUserAgent(LPCWSTR userAgent);

    HRESULT updateBounds(RECT& bounds);
    HRESULT getBounds(RECT& bounds);
    HRESULT setVisible(bool isVisible);
    HRESULT setBackgroundColor(int32_t argb);
    HRESULT requestFocus(bool isNext);

    bool canGoBack();
    bool canGoForward();
    void goBack();
    void goForward();
    void reload();
    void cancelNavigate();

    HRESULT clearCache();
    HRESULT clearCookies();
    HRESULT getCookies(LPCWSTR url, WebViewCookieCallback callback);
    HRESULT setCookie(LPCWSTR name, LPCWSTR value, LPCWSTR domain,
        LPCWSTR path);

	HRESULT suspend();
	HRESULT resume();

    void askFlutterPermission(wil::com_ptr<ICoreWebView2PermissionRequestedEventArgs> args, OnAskPermissionFunc onAskPermission);
    void MyWebViewImpl::grantPermission(int deferralId, BOOL isGranted);

    void openDevTools() override;

private:
    MyWebViewCreateParams m_params;
    bool m_isNowGoBackForward = false;

    bool isSameOriginRequest(const std::wstring& requestUri) const;
    bool isFnosGatewayRequest(const std::wstring& requestUri) const;
    HRESULT applyRequestHeaders(
        ICoreWebView2HttpRequestHeaders* requestHeaders,
        bool includeAuthorization = true) const;

    void __sendOnNavigationRequest(std::wstring utf16Url, std::string utf8Url, bool isNewWindow);
    void __sendOnPageStarted(std::string url, UINT64 navigationId);

    std::map<UINT64, std::string> m_navigationMap;
    std::map<int, std::wstring> m_navigationRequestMap;
    int m_lastNavigationRequestId = 0;
  	bool m_hasNavigationDecision = false;

    std::wstring nowLoadingUrl;

    std::wstring m_requestHeaderOrigin;
    std::map<std::wstring, std::wstring> m_requestHeaders;
    bool m_hasRequestHeaderHandler = false;
    EventRegistrationToken m_webResourceRequestedToken = {};

    template<class T> wil::com_ptr<T> getProfile();

    std::map<std::wstring, std::wstring> channelMap; // channel name -> id of RemoveScriptToExecuteOnDocumentCreated
    bool m_hasRegisteredChannel = false;

    std::map<int, std::pair< wil::com_ptr<ICoreWebView2PermissionRequestedEventArgs>, wil::com_ptr<ICoreWebView2Deferral> >> permissionArgsMap;
    int m_lastPermissionDeferralId = 0;

    wil::com_ptr<ICoreWebView2> m_pWebview;
    wil::com_ptr<ICoreWebView2Controller> m_pController;
    wil::com_ptr<ICoreWebView2Settings> m_pSettings;
    RECT m_bounds = { 0,0,0,0 };
};
wil::com_ptr<ICoreWebView2Environment> g_env;

// --------------------------------------------------------------------------

MyWebView* MyWebView::Create(HWND hWnd,
    MyWebViewCreateParams params,
    PCWSTR pwUserDataFolder,
    PCWSTR pwProfileName)
{
    return new MyWebViewImpl(hWnd, params, pwUserDataFolder, pwProfileName);
}

HRESULT InitWebViewRuntime(PCWSTR pwUserDataFolder, std::function<void(HRESULT)> callback = nullptr)
{
    if (g_env != NULL) {
        if (callback != nullptr) callback(S_OK);
        return S_OK;
    }

    return CreateCoreWebView2EnvironmentWithOptions(nullptr, pwUserDataFolder, nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [callback](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {
                if (result == S_OK) {
                    g_env = env;
                }
                if (callback != nullptr) callback(result);
                return result;
            }).Get());
}

HRESULT ReleaseWebViewRuntime()
{
    return S_OK;
}

MyWebViewImpl::MyWebViewImpl(HWND hWnd,
    MyWebViewCreateParams params,
    PCWSTR pwUserDataFolder = NULL,
    PCWSTR pwProfileName = NULL) : m_params(params)
{
    std::wstring profileName = (pwProfileName != NULL) ? pwProfileName : L"";

    InitWebViewRuntime(pwUserDataFolder, [=](HRESULT hr) -> void {
        if (hr != S_OK) {
            params.onCreated(hr, NULL);
            return;
        }

        // Lambda that handles the controller after creation (shared by both paths)
        auto onControllerCreated = Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
            [=](HRESULT hr, ICoreWebView2Controller* controller) -> HRESULT {
                if (hr != S_OK) {
                    params.onCreated(hr, NULL);
                    return hr;
                }

                hr = controller->get_CoreWebView2(&m_pWebview);
                hr = m_pWebview->get_Settings(&m_pSettings);
                m_pController = controller;

                const auto visibleHr = m_pController->put_IsVisible(TRUE);
                std::cout << "[webview_win_floating] controller visible hr="
                          << visibleHr << std::endl;

                m_pSettings->put_AreDefaultContextMenusEnabled(FALSE);
#ifndef _DEBUG
                m_pSettings->put_AreDevToolsEnabled(FALSE);
#endif

                m_pWebview->add_NavigationStarting(
                    Callback<ICoreWebView2NavigationStartingEventHandler>(
                        [=](ICoreWebView2* sender, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {

                            wil::unique_cotaskmem_string url;
                            args->get_Uri(&url);
                            auto utf16Url = std::wstring(url.get());
                            auto utf8Url = utf8_encode(utf16Url);

                            BOOL isRedirected = FALSE;
                            args->get_IsRedirected(&isRedirected);

                            BOOL isPostMethod = FALSE;
                            wil::com_ptr<ICoreWebView2HttpRequestHeaders> headers;
                            args->get_RequestHeaders(&headers);
                            if (headers != nullptr) {
                                // http POST method always set "Content-Type" header,
                                // so if "Content-Type" header exists,
                                // always allow navigation, without asking client code in dart side.
                                // If we skip the POST request below, all the headers will be discard,
                                // so the POST request will be failed, and this makes most of the html login-form failed.
                                headers->Contains(L"Content-Type", &isPostMethod);
                                const bool sameOrigin =
                                    isSameOriginRequest(utf16Url);
                                const bool gatewayOrigin =
                                    isFnosGatewayRequest(utf16Url);
                                HRESULT headerHr = S_OK;
                                if (sameOrigin) {
                                    headerHr = applyRequestHeaders(headers.get());
                                } else if (gatewayOrigin) {
                                    // A fnOS validation redirect may move from
                                    // the FNID host to fnos.net. Forward only
                                    // gateway cookies there; never forward the
                                    // Ting Reader JWT to the fnOS login host.
                                    headerHr = applyRequestHeaders(
                                        headers.get(), false);
                                }

                                const auto queryPosition =
                                    utf16Url.find_first_of(L"?#");
                                const auto safeUrl = utf16Url.substr(
                                    0, queryPosition == std::wstring::npos
                                           ? std::wstring::npos
                                           : queryPosition);
                                BOOL hasCookie = FALSE;
                                BOOL hasAuthorization = FALSE;
                                headers->Contains(L"Cookie", &hasCookie);
                                headers->Contains(
                                    L"Authorization", &hasAuthorization);
                                std::cout
                                    << "[webview_win_floating] navigation request"
                                    << " url=" << utf8_encode(safeUrl)
                                    << " same_origin=" << (sameOrigin ? 1 : 0)
                                    << " gateway_origin="
                                    << (gatewayOrigin ? 1 : 0)
                                    << " redirected=" << (isRedirected ? 1 : 0)
                                    << " hr=" << headerHr
                                    << " cookie=" << (hasCookie ? 1 : 0)
                                    << " authorization="
                                    << (hasAuthorization ? 1 : 0)
                                    << std::endl;
                            }

                            bool userInitiated = true;
                            if (m_isNowGoBackForward
                                || isPostMethod == TRUE
                                || isRedirected == TRUE
                                || nowLoadingUrl.compare(url.get()) == 0
                                || utf16Url.rfind(L"data:text/html;", 0) == 0) {
                                // is triggered by loadUrl() or loadHtmlString(), not user initiated
                                // or is triggered by goBack / goForward
                                // then we don't ask client Dart code (onNavigationRequest) to allow/prevent loading url
                                nowLoadingUrl = L"";
                                m_isNowGoBackForward = false;
                                userInitiated = false;
                            }


                            if (m_hasNavigationDecision && userInitiated) {
                                // for a user-initiated request,
                                // cancel the request first, 
                                // and ask dart code to grant/deny this request
                                // if dart code deny, nothing happen
                                // if dart code grant, call loadUrl() to load url again
                                // Windows WebView2 doesn't support asynchronous decision,
                                // so we must cancel the request here, before dart code make decision
                                args->put_Cancel(TRUE);
                                __sendOnNavigationRequest(utf16Url, utf8Url, false);
                            } else {
                                // for a non-user-initiated request,
                                // just allow the request, and notify dart code onPageStarted()
                                UINT64 navigationId;
                                args->get_NavigationId(&navigationId);
                                __sendOnPageStarted(utf8Url, navigationId);
                            }                            
                            return S_OK;
                        }).Get(), NULL);

                m_pWebview->add_NewWindowRequested(
                    Callback<ICoreWebView2NewWindowRequestedEventHandler>(
                        [=](ICoreWebView2* sender, ICoreWebView2NewWindowRequestedEventArgs* args) -> HRESULT {
                            wil::unique_cotaskmem_string url;
                            args->get_Uri(&url);
                            auto utf16Url = std::wstring(url.get());
                            auto utf8Url = utf8_encode(utf16Url);

                            if (m_hasNavigationDecision) {
                                __sendOnNavigationRequest(utf16Url, utf8Url, true);
                            } else {
                                loadUrl(url.get());
                            }

                            args->put_Handled(TRUE); // ignore default handler
                            return S_OK;
                        }).Get(), NULL);

                m_pWebview->add_NavigationCompleted(
                    Callback<ICoreWebView2NavigationCompletedEventHandler>(
                        [=](ICoreWebView2* sender, ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
                            UINT64 navigationId = 0;
                            args->get_NavigationId(&navigationId);
                            std::string url;
                            const auto navigationIt = m_navigationMap.find(navigationId);
                            if (navigationIt != m_navigationMap.end()) {
                                url = navigationIt->second;
                                m_navigationMap.erase(navigationIt);
                            }

                            wil::unique_cotaskmem_string source;
                            sender->get_Source(&source);
                            const std::string sourceUrl =
                                source.get() == nullptr
                                    ? std::string()
                                    : utf8_encode(std::wstring(source.get()));
                            const std::string completedUrl =
                                sourceUrl.empty() ? url : sourceUrl;
                            const auto sourceQuery = completedUrl.find_first_of("?#");
                            const std::string safeCompletedUrl =
                                completedUrl.substr(
                                    0,
                                    sourceQuery == std::string::npos
                                        ? std::string::npos
                                        : sourceQuery);

                            int httpStatusCode = 0;
                            wil::com_ptr<ICoreWebView2NavigationCompletedEventArgs> baseArgs = args;
                            auto args2 = baseArgs.try_query<ICoreWebView2NavigationCompletedEventArgs2>();
                            if (args2 != nullptr) {
                                args2->get_HttpStatusCode(&httpStatusCode);
                            }
                            BOOL success = FALSE;
                            args->get_IsSuccess(&success);
                            COREWEBVIEW2_WEB_ERROR_STATUS webErrorStatus =
                                COREWEBVIEW2_WEB_ERROR_STATUS_UNKNOWN;
                            args->get_WebErrorStatus(&webErrorStatus);
                            std::cout
                                << "[webview_win_floating] navigation completed"
                                << " initial_url=" << url
                                << " source=" << safeCompletedUrl
                                << " status=" << httpStatusCode
                                << " success=" << (success ? 1 : 0)
                                << " web_error=" << static_cast<int>(webErrorStatus)
                                << std::endl;
                            if (httpStatusCode >= 400) {
                                params.onHttpError(completedUrl, httpStatusCode);
                                params.onPageFinished(completedUrl);
                                return S_OK;
                            }

                            if (success) {
                                params.onPageFinished(completedUrl);
                                return S_OK;
                            }

                            int errCode = webErrorStatus;

                            // SSL certification error
                            switch (errCode) {
                                case COREWEBVIEW2_WEB_ERROR_STATUS_OPERATION_CANCELED:
                                    // user cancel navigation, or deny navigation. 
                                    // ignore this error
                                    return S_OK;
                                case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_COMMON_NAME_IS_INCORRECT:
                                case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_EXPIRED:
                                case COREWEBVIEW2_WEB_ERROR_STATUS_CLIENT_CERTIFICATE_CONTAINS_ERRORS:
                                case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_REVOKED:
                                case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID:
                                    // for SSL certificate error
                                    params.onSslAuthError(completedUrl);
                                    params.onPageFinished(completedUrl);
                                    return S_OK;
                            }

                            // other non-http and non-ssl error
                            const char *errType = NULL;
                            switch (errCode) {
                                case COREWEBVIEW2_WEB_ERROR_STATUS_SERVER_UNREACHABLE:
                                    errType = "hostLookup";
                                    break;
                                case COREWEBVIEW2_WEB_ERROR_STATUS_TIMEOUT:
                                    errType = "timeout";
                                    break;
                                case COREWEBVIEW2_WEB_ERROR_STATUS_CONNECTION_ABORTED:
                                case COREWEBVIEW2_WEB_ERROR_STATUS_CONNECTION_RESET:
                                case COREWEBVIEW2_WEB_ERROR_STATUS_DISCONNECTED:
                                case COREWEBVIEW2_WEB_ERROR_STATUS_CANNOT_CONNECT:
                                    errType = "connect";
                                    break;
                                case COREWEBVIEW2_WEB_ERROR_STATUS_HOST_NAME_NOT_RESOLVED:
                                    errType = "hostLookup";
                                    break;
                                case COREWEBVIEW2_WEB_ERROR_STATUS_REDIRECT_FAILED:
                                    errType = "redirectLoop";
                                    break;
                                case COREWEBVIEW2_WEB_ERROR_STATUS_VALID_AUTHENTICATION_CREDENTIALS_REQUIRED:
                                    errType = "authentication";
                                    break;
                                case COREWEBVIEW2_WEB_ERROR_STATUS_VALID_PROXY_AUTHENTICATION_REQUIRED:
                                    errType = "proxyAuthentication";
                                    break;
                                case COREWEBVIEW2_WEB_ERROR_STATUS_ERROR_HTTP_INVALID_SERVER_RESPONSE:
                                case COREWEBVIEW2_WEB_ERROR_STATUS_OPERATION_CANCELED:
                                case COREWEBVIEW2_WEB_ERROR_STATUS_UNEXPECTED_ERROR:
                                default:
                                    errType = "unknown";
                                    break;
                            }
                            if (errType != NULL) {
                                // std::cout << "[native] errCode: " << errCode << std::endl;
                                params.onWebResourceError(
                                    completedUrl, errCode, errType);
                                params.onPageFinished(completedUrl);
                            }

                            return S_OK;
                        }).Get(), NULL);

                m_pWebview->add_DocumentTitleChanged(
                    Callback<ICoreWebView2DocumentTitleChangedEventHandler>(
                        [=](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
                            wil::unique_cotaskmem_string title;
                            HRESULT hr = sender->get_DocumentTitle(&title);
                            if (FAILED(hr)) return S_OK;

                            auto utf8Title = utf8_encode(std::wstring(title.get()));
                            std::cout << "[webview_win_floating] document title="
                                      << utf8Title << std::endl;
                            params.onPageTitleChanged(utf8Title);
                            return S_OK;
                        }).Get(), NULL);

                m_pWebview->add_HistoryChanged(
                    Callback<ICoreWebView2HistoryChangedEventHandler>(
                        [=](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
                            if (params.onHistoryChanged) {
                                params.onHistoryChanged();
                            }

                            return S_OK;
                        })
                        .Get(), NULL);

                hr = m_pWebview->add_WebMessageReceived(
                    Callback<ICoreWebView2WebMessageReceivedEventHandler>(
                        [=](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT {
                            if (params.onWebMessageReceived != NULL) {
                                wil::unique_cotaskmem_string json;
                                HRESULT hr = args->get_WebMessageAsJson(&json);
                                if (SUCCEEDED(hr)) {
                                    std::cout
                                        << "[webview_win_floating] web message received"
                                        << " length="
                                        << (json.get() == nullptr
                                                ? 0
                                                : wcslen(json.get()))
                                        << std::endl;
                                    params.onWebMessageReceived(Utf8FromUtf16(json.get()));
                                }
                            }
                            return S_OK;
                        }).Get(), NULL); /// &m_webMessageReceivedToken

                hr = m_pController->add_MoveFocusRequested(
                    Callback<ICoreWebView2MoveFocusRequestedEventHandler>(
                        [=](ICoreWebView2Controller* sender, ICoreWebView2MoveFocusRequestedEventArgs* args) -> HRESULT {
                            COREWEBVIEW2_MOVE_FOCUS_REASON reason;
                            args->get_Reason(&reason);
                            params.onMoveFocusRequest(reason == COREWEBVIEW2_MOVE_FOCUS_REASON_NEXT);
                            return S_OK;
                        }).Get(), NULL);

                hr = m_pWebview->add_ContainsFullScreenElementChanged(
                    Callback<ICoreWebView2ContainsFullScreenElementChangedEventHandler>(
                        [=](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
                            BOOL isFullScreen;
                            m_pWebview->get_ContainsFullScreenElement(&isFullScreen);
                            params.onFullScreenChanged(isFullScreen);
                            return S_OK;
                        })
                    .Get(), nullptr);

                hr = m_pWebview->add_PermissionRequested(
                    Callback<ICoreWebView2PermissionRequestedEventHandler>(
                        [=](ICoreWebView2* sender, ICoreWebView2PermissionRequestedEventArgs* args) -> HRESULT {
                            askFlutterPermission(args, params.onAskPermission);                           
                            return S_OK;
                    }).Get(), NULL);

                params.onCreated(hr, this);
                return hr;
            });

        // If a profileName is specified, use ICoreWebView2Environment10 to create
        // a controller with profile-based isolation (shared process, separate sessions).
        // See: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/multi-profile-support
        if (!profileName.empty()) {
            auto env10 = g_env.try_query<ICoreWebView2Environment10>();
            if (env10 != NULL) {
                wil::com_ptr<ICoreWebView2ControllerOptions> options;
                HRESULT optHr = env10->CreateCoreWebView2ControllerOptions(&options);
                if (SUCCEEDED(optHr) && options != NULL) {
                    options->put_ProfileName(profileName.c_str());
                    env10->CreateCoreWebView2ControllerWithOptions(hWnd, options.get(), onControllerCreated.Get());
                    return;
                }
                std::cout << "[webview_win_floating] CreateCoreWebView2ControllerOptions failed, falling back to default controller" << std::endl;
            } else {
                std::cout << "[webview_win_floating] ICoreWebView2Environment10 not available, profileName ignored" << std::endl;
            }
        }

        // Standard path: no profile name, or profile API unavailable
        g_env->CreateCoreWebView2Controller(hWnd, onControllerCreated.Get());
        });
}

void MyWebViewImpl::askFlutterPermission(wil::com_ptr<ICoreWebView2PermissionRequestedEventArgs> args, OnAskPermissionFunc onAskPermission)
{
    wil::com_ptr<ICoreWebView2Deferral> deferral;
    COREWEBVIEW2_PERMISSION_KIND kind;                           
    wil::unique_cotaskmem_string uri;

    args->get_PermissionKind(&kind);
    args->get_Uri(&uri);
    args->GetDeferral(&deferral);

    int deferralId = ++m_lastPermissionDeferralId;
    permissionArgsMap[deferralId] = std::pair(args, deferral);
    onAskPermission(utf8_encode(std::wstring(uri.get())), kind, deferralId);
}

void MyWebViewImpl::grantPermission(int deferralId, BOOL isGranted)
{
    auto it = permissionArgsMap.find(deferralId);
    if (it == permissionArgsMap.end()) return; // not found

    auto pair = std::move(it->second);
    permissionArgsMap.erase(it);

    auto args = pair.first;
    auto deferral = pair.second;

    auto state = isGranted ? COREWEBVIEW2_PERMISSION_STATE_ALLOW : COREWEBVIEW2_PERMISSION_STATE_DENY;
    args->put_State(state);
    deferral->Complete();
}

MyWebViewImpl::~MyWebViewImpl()
{
    if (m_pWebview != nullptr && m_hasRequestHeaderHandler) {
        m_pWebview->remove_WebResourceRequested(m_webResourceRequestedToken);
        m_pWebview->RemoveWebResourceRequestedFilter(
            L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
        m_hasRequestHeaderHandler = false;
    }
    if (m_pController != nullptr) m_pController->Close();
    std::cout << "[webview_win_floating] MyWebViewImpl::~MyWebViewImpl()" << std::endl;
}

void MyWebViewImpl::setHasNavigationDecision(bool hasNavigationDecision)
{
    m_hasNavigationDecision = hasNavigationDecision;
}

void MyWebViewImpl::__sendOnNavigationRequest(std::wstring utf16Url, std::string utf8Url, bool isNewWindow) {
    m_lastNavigationRequestId++;
    m_navigationRequestMap[m_lastNavigationRequestId] = utf16Url;
    m_params.onNavigationRequest(m_lastNavigationRequestId, utf8Url, isNewWindow);
}

void MyWebViewImpl::__sendOnPageStarted(std::string url, UINT64 navigationId) {
    m_navigationMap[navigationId] = url;
    m_params.onPageStarted(url);

    // TODO: 
    // how to listen url change in WebView2 ?
    // we simulate 'onUrlChange' event here
    // but this cannot detect any url changed by javascript pushState()...
    m_params.onUrlChange(url);
}

void MyWebViewImpl::allowNavigationRequest(int requestId, bool isAllowed) {
    if (isAllowed) {
        auto utf16Url = m_navigationRequestMap[requestId];
        loadUrl(utf16Url.c_str());
    }
    m_navigationRequestMap.erase(requestId);
}

HRESULT MyWebViewImpl::loadUrl(LPCWSTR url)
{
    nowLoadingUrl = url;
    return m_pWebview->Navigate(url);
}

bool MyWebViewImpl::isSameOriginRequest(
    const std::wstring& requestUri) const
{
    if (m_requestHeaderOrigin.empty()) return false;

    std::wstring lowerRequest = requestUri;
    std::wstring lowerOrigin = m_requestHeaderOrigin;
    std::transform(lowerRequest.begin(), lowerRequest.end(),
                   lowerRequest.begin(), [](wchar_t value) {
                     return static_cast<wchar_t>(std::towlower(value));
                   });
    std::transform(lowerOrigin.begin(), lowerOrigin.end(),
                   lowerOrigin.begin(), [](wchar_t value) {
                     return static_cast<wchar_t>(std::towlower(value));
                   });

    const size_t originLength = lowerOrigin.length();
    return lowerRequest == lowerOrigin ||
        (lowerRequest.length() > originLength &&
         lowerRequest.compare(0, originLength, lowerOrigin) == 0 &&
         (lowerRequest[originLength] == L'/' ||
          lowerRequest[originLength] == L'?'));
}

bool MyWebViewImpl::isFnosGatewayRequest(
    const std::wstring& requestUri) const
{
    const auto schemeEnd = requestUri.find(L"://");
    if (schemeEnd == std::wstring::npos) return false;

    const auto hostStart = schemeEnd + 3;
    const auto hostEnd = requestUri.find_first_of(L"/?#", hostStart);
    std::wstring host = requestUri.substr(
        hostStart,
        hostEnd == std::wstring::npos ? std::wstring::npos
                                      : hostEnd - hostStart);
    const auto port = host.find(L':');
    if (port != std::wstring::npos) host.resize(port);
    std::transform(host.begin(), host.end(), host.begin(), [](wchar_t value) {
        return static_cast<wchar_t>(std::towlower(value));
    });

    if (host == L"fnos.net") return true;
    const std::wstring suffix = L".fnos.net";
    return host.length() > suffix.length() &&
           host.compare(host.length() - suffix.length(), suffix.length(),
                        suffix) == 0;
}

HRESULT MyWebViewImpl::applyRequestHeaders(
    ICoreWebView2HttpRequestHeaders* requestHeaders,
    bool includeAuthorization) const
{
    if (requestHeaders == nullptr || m_requestHeaders.empty()) return S_OK;

    HRESULT firstFailure = S_OK;
    for (const auto& header : m_requestHeaders) {
        if (!includeAuthorization) {
            // Cross-host fnOS redirects get only the gateway cookie. The Ting
            // Reader bearer token must remain scoped to the app host.
            if (_wcsicmp(header.first.c_str(), L"Cookie") != 0) {
                continue;
            }
        }
        const auto hr = requestHeaders->SetHeader(
            header.first.c_str(), header.second.c_str());
        if (FAILED(hr)) {
            if (SUCCEEDED(firstFailure)) firstFailure = hr;
            std::cerr << "[webview_win_floating] failed to set request header "
                      << utf8_encode(header.first) << ", hr=" << hr << std::endl;
        }
    }
    return firstFailure;
}

HRESULT MyWebViewImpl::setRequestHeaders(
    LPCWSTR origin,
    const std::map<std::wstring, std::wstring>& headers)
{
    m_requestHeaderOrigin = origin == nullptr ? L"" : origin;
    m_requestHeaders = headers;
    std::cout << "[webview_win_floating] setRequestHeaders origin="
              << utf8_encode(m_requestHeaderOrigin)
              << " count=" << m_requestHeaders.size() << " names=";
    bool firstHeader = true;
    for (const auto& header : m_requestHeaders) {
        if (!firstHeader) std::cout << ",";
        std::cout << utf8_encode(header.first);
        firstHeader = false;
    }
    std::cout << std::endl;
    if (m_hasRequestHeaderHandler) return S_OK;

    HRESULT hr = m_pWebview->AddWebResourceRequestedFilter(
        L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
    if (FAILED(hr)) {
        std::cerr << "[webview_win_floating] add web resource filter failed"
                  << " hr=" << hr << std::endl;
        return hr;
    }

    hr = m_pWebview->add_WebResourceRequested(
        Callback<ICoreWebView2WebResourceRequestedEventHandler>(
            [this](ICoreWebView2* sender,
                   ICoreWebView2WebResourceRequestedEventArgs* args)
                -> HRESULT {
              if (m_requestHeaderOrigin.empty() || m_requestHeaders.empty()) {
                return S_OK;
              }

              wil::com_ptr<ICoreWebView2WebResourceRequest> request;
              HRESULT requestHr = args->get_Request(&request);
              if (FAILED(requestHr) || request == nullptr) {
                std::cerr
                    << "[webview_win_floating] web resource get request failed"
                    << " hr=" << requestHr << std::endl;
                return S_OK;
              }

              wil::unique_cotaskmem_string uri;
              requestHr = request->get_Uri(&uri);
              if (FAILED(requestHr) || uri.get() == nullptr) {
                std::cerr
                    << "[webview_win_floating] web resource get uri failed"
                    << " hr=" << requestHr << std::endl;
                return S_OK;
              }

              const std::wstring requestUri(uri.get());
              const bool sameOrigin = isSameOriginRequest(requestUri);
              const bool gatewayOrigin = isFnosGatewayRequest(requestUri);
              if (!sameOrigin && !gatewayOrigin) return S_OK;

              wil::com_ptr<ICoreWebView2HttpRequestHeaders> requestHeaders;
              requestHr = request->get_Headers(&requestHeaders);
              if (FAILED(requestHr) || requestHeaders == nullptr) {
                std::cerr
                    << "[webview_win_floating] web resource get headers failed"
                    << " hr=" << requestHr << std::endl;
                return S_OK;
              }

              const auto headerHr = applyRequestHeaders(
                  requestHeaders.get(), sameOrigin);
              BOOL hasCookie = FALSE;
              BOOL hasAuthorization = FALSE;
              requestHeaders->Contains(L"Cookie", &hasCookie);
              requestHeaders->Contains(L"Authorization", &hasAuthorization);
              const auto queryPosition = requestUri.find_first_of(L"?#");
              const auto safeUri = requestUri.substr(
                  0, queryPosition == std::wstring::npos
                         ? std::wstring::npos
                         : queryPosition);
              std::cout << "[webview_win_floating] web resource headers applied"
                        << " url=" << utf8_encode(safeUri)
                        << " hr=" << headerHr
                        << " same_origin=" << (sameOrigin ? 1 : 0)
                        << " gateway_origin=" << (gatewayOrigin ? 1 : 0)
                        << " cookie=" << (hasCookie ? 1 : 0)
                        << " authorization=" << (hasAuthorization ? 1 : 0)
                        << std::endl;
              return S_OK;
            })
            .Get(),
        &m_webResourceRequestedToken);
    if (SUCCEEDED(hr)) {
        m_hasRequestHeaderHandler = true;
        std::cout << "[webview_win_floating] web resource handler installed"
                  << std::endl;
    } else {
        std::cerr << "[webview_win_floating] add web resource handler failed"
                  << " hr=" << hr << std::endl;
    }
    return hr;
}

HRESULT MyWebViewImpl::loadHtmlString(LPCWSTR html)
{
    return m_pWebview->NavigateToString(html);
}

HRESULT MyWebViewImpl::runJavascript(LPCWSTR javaScriptString, bool ignoreResult, std::function<void(std::string)> callback)
{
    return m_pWebview->ExecuteScript(javaScriptString, Callback<ICoreWebView2ExecuteScriptCompletedHandler >(
        [callback, ignoreResult](HRESULT hr, LPCWSTR resultObjectAsJson) -> HRESULT {
            if (FAILED(hr)) {
                std::cerr << "[webview_win_floating] ExecuteScript failed"
                          << " hr=" << hr << std::endl;
            }
            if (callback != nullptr) {
                if (ignoreResult) callback("");
                else if (resultObjectAsJson == nullptr) callback("null");
                else callback(utf8_encode(std::wstring(resultObjectAsJson)));
            }
            return hr;
        }).Get());
}

HRESULT MyWebViewImpl::addScriptChannelByName(
    LPCWSTR channelName, std::function<void(HRESULT)> callback)
{
    if (channelName == nullptr || wcslen(channelName) > 30) return E_INVALIDARG;

    const std::wstring channelNameCopy(channelName);
    auto addChannelScript = [this, channelNameCopy, callback]() -> HRESULT {
        const std::wstring script =
            L"const " + channelNameCopy + L" = new JkChannel('" +
            channelNameCopy + L"');";
        return m_pWebview->AddScriptToExecuteOnDocumentCreated(
            script.c_str(),
            Callback<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler>(
                [this, channelNameCopy, callback](HRESULT error, PCWSTR id)
                    -> HRESULT {
                  if (SUCCEEDED(error) && id != nullptr) {
                    channelMap[channelNameCopy] = id;
                  }
                  if (callback != nullptr) callback(error);
                  return S_OK;
                })
                .Get());
    };

    if (m_hasRegisteredChannel) return addChannelScript();

    LPCWSTR script =
        L"class JkChannel { constructor(name) { this.name = name; } "
        L"postMessage(message) { window.chrome.webview.postMessage({"
        L"'JkChannelName': this.name, 'msg' : message}); } }";
    HRESULT hr = m_pWebview->AddScriptToExecuteOnDocumentCreated(
        script,
        Callback<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler>(
            [this, addChannelScript, callback](HRESULT error, PCWSTR id)
                -> HRESULT {
              if (FAILED(error)) {
                if (callback != nullptr) callback(error);
                return S_OK;
              }
              m_hasRegisteredChannel = true;
              const HRESULT channelHr = addChannelScript();
              if (FAILED(channelHr) && callback != nullptr) {
                callback(channelHr);
              }
              return S_OK;
            })
            .Get());
    return hr;
}

void MyWebViewImpl::removeScriptChannelByName(LPCWSTR channelName)
{
    std::wstring key = channelName;
    if (channelMap.find(key) != channelMap.end())
    {
        std::wstring id = channelMap[key];
        m_pWebview->RemoveScriptToExecuteOnDocumentCreated(id.c_str());
        channelMap.erase(key);
    }
}

HRESULT MyWebViewImpl::updateBounds(RECT& bounds)
{
    m_bounds = bounds;
    const auto hr = m_pController->put_Bounds(bounds);
    std::cout << "[webview_win_floating] bounds"
              << " left=" << bounds.left
              << " top=" << bounds.top
              << " right=" << bounds.right
              << " bottom=" << bounds.bottom
              << " hr=" << hr << std::endl;
    return hr;
}

HRESULT MyWebViewImpl::getBounds(RECT& bounds)
{
    bounds = m_bounds;
    return S_OK;
}

HRESULT MyWebViewImpl::setVisible(bool isVisible)
{
    const auto hr = m_pController->put_IsVisible(isVisible);
    std::cout << "[webview_win_floating] visibility="
              << (isVisible ? 1 : 0) << " hr=" << hr << std::endl;
    return hr;
}

HRESULT MyWebViewImpl::setBackgroundColor(int32_t argb)
{
    COREWEBVIEW2_COLOR value;
    value.R = GetBValue(argb);
    value.G = GetGValue(argb);
    value.B = GetRValue(argb);
    value.A = 255;
    wil::com_ptr<ICoreWebView2Controller2> controller2 = m_pController.query<ICoreWebView2Controller2>();
    return controller2->put_DefaultBackgroundColor(value);
}

HRESULT MyWebViewImpl::requestFocus(bool isNext)
{
    m_pController->MoveFocus(isNext ? COREWEBVIEW2_MOVE_FOCUS_REASON_NEXT : COREWEBVIEW2_MOVE_FOCUS_REASON_PREVIOUS);
    return S_OK;
}

void MyWebViewImpl::enableJavascript(bool bEnable)
{
    m_pSettings->put_IsScriptEnabled(bEnable);
}

void MyWebViewImpl::enableStatusBar(bool bEnable)
{
    m_pSettings->put_IsStatusBarEnabled(bEnable);
}

void MyWebViewImpl::enableIsZoomControl(bool bEnable)
{
    m_pSettings->put_IsZoomControlEnabled(bEnable);
}

HRESULT MyWebViewImpl::setUserAgent(LPCWSTR userAgent)
{
    wil::com_ptr<ICoreWebView2Settings2> pSettings2;
    HRESULT hr = m_pSettings->QueryInterface(&pSettings2);
    if (SUCCEEDED(hr)) {
        hr = pSettings2->put_UserAgent(userAgent);
        return hr;
    }
    return E_FAIL;
}

bool MyWebViewImpl::canGoBack()
{
    BOOL value = FALSE;
    m_pWebview->get_CanGoBack(&value);
    return value;
}

bool MyWebViewImpl::canGoForward()
{
    BOOL value = FALSE;
    m_pWebview->get_CanGoForward(&value);
    return value;
}

void MyWebViewImpl::goBack()
{
    m_isNowGoBackForward = true;
    m_pWebview->GoBack();
}

void MyWebViewImpl::goForward()
{
    m_isNowGoBackForward = true;
    m_pWebview->GoForward();
}

void MyWebViewImpl::reload()
{
    m_pWebview->Reload();
}

void MyWebViewImpl::cancelNavigate()
{
    m_pWebview->Stop();
}

template<class T> wil::com_ptr<T> MyWebViewImpl::getProfile() {
    static_assert(std::is_base_of<ICoreWebView2Profile, T>::value, "T must inherit from <ICoreWebView2Profile>");
    wil::com_ptr<ICoreWebView2Profile> pProfile;

    auto pWebView_13 = m_pWebview.try_query<ICoreWebView2_13>();
    if (pWebView_13 != NULL) {
        pWebView_13->get_Profile(&pProfile);
    }

    if (pProfile == NULL) return wil::com_ptr<T>();
    return pProfile.try_query<T>();
}

HRESULT MyWebViewImpl::clearCache()
{
    HRESULT hr = E_FAIL;
    auto pProfile_2 = getProfile<ICoreWebView2Profile2>();
    if (pProfile_2 != NULL) {
        hr = pProfile_2->ClearBrowsingDataAll(NULL);
    }
    return hr;
}

HRESULT MyWebViewImpl::clearCookies()
{
    wil::com_ptr<ICoreWebView2CookieManager> cookieManager;
    auto webview2_2 = m_pWebview.try_query<ICoreWebView2_2>();
    if (webview2_2 == NULL) return E_FAIL;

    webview2_2->get_CookieManager(&cookieManager);
    if (cookieManager == NULL) return E_FAIL;

    return cookieManager->DeleteAllCookies();
}

HRESULT MyWebViewImpl::getCookies(LPCWSTR url, WebViewCookieCallback callback)
{
    wil::com_ptr<ICoreWebView2CookieManager> cookieManager;
    auto webview2_2 = m_pWebview.try_query<ICoreWebView2_2>();
    if (webview2_2 == NULL) return E_FAIL;

    HRESULT hr = webview2_2->get_CookieManager(&cookieManager);
    if (FAILED(hr) || cookieManager == NULL) return FAILED(hr) ? hr : E_FAIL;

    return cookieManager->GetCookies(
        url,
        Callback<ICoreWebView2GetCookiesCompletedHandler>(
            [callback](HRESULT result, ICoreWebView2CookieList* cookieList)
                -> HRESULT {
              std::vector<WebViewCookieData> cookies;
              if (SUCCEEDED(result) && cookieList != nullptr) {
                UINT count = 0;
                HRESULT countResult = cookieList->get_Count(&count);
                if (FAILED(countResult)) {
                  callback(countResult, std::move(cookies));
                  return S_OK;
                }

                for (UINT index = 0; index < count; ++index) {
                  wil::com_ptr<ICoreWebView2Cookie> cookie;
                  if (FAILED(cookieList->GetValueAtIndex(index, &cookie)) ||
                      cookie == nullptr) {
                    continue;
                  }

                  wil::unique_cotaskmem_string name;
                  wil::unique_cotaskmem_string value;
                  wil::unique_cotaskmem_string domain;
                  wil::unique_cotaskmem_string path;
                  if (FAILED(cookie->get_Name(&name)) ||
                      FAILED(cookie->get_Value(&value)) ||
                      FAILED(cookie->get_Domain(&domain)) ||
                      FAILED(cookie->get_Path(&path))) {
                    continue;
                  }

                  cookies.push_back({
                      utf8_encode(name.get() == nullptr
                                      ? std::wstring()
                                      : std::wstring(name.get())),
                      utf8_encode(value.get() == nullptr
                                      ? std::wstring()
                                      : std::wstring(value.get())),
                      utf8_encode(domain.get() == nullptr
                                      ? std::wstring()
                                      : std::wstring(domain.get())),
                      utf8_encode(path.get() == nullptr
                                      ? std::wstring()
                                      : std::wstring(path.get())),
                  });
                }
              }

              callback(result, std::move(cookies));
              return S_OK;
            })
            .Get());
}

HRESULT MyWebViewImpl::setCookie(LPCWSTR name, LPCWSTR value, LPCWSTR domain,
                                 LPCWSTR path)
{
    wil::com_ptr<ICoreWebView2CookieManager> cookieManager;
    auto webview2_2 = m_pWebview.try_query<ICoreWebView2_2>();
    if (webview2_2 == NULL) return E_FAIL;

    HRESULT hr = webview2_2->get_CookieManager(&cookieManager);
    if (FAILED(hr) || cookieManager == NULL) return FAILED(hr) ? hr : E_FAIL;

    wil::com_ptr<ICoreWebView2Cookie> cookie;
    hr = cookieManager->CreateCookie(name, value, domain, path, &cookie);
    if (FAILED(hr) || cookie == nullptr) return FAILED(hr) ? hr : E_FAIL;

    const std::wstring domainValue =
        domain == nullptr ? std::wstring() : std::wstring(domain);
    const std::wstring fnosSuffix = L".fnos.net";
    const bool isFnosDomain =
        domainValue == L"fnos.net" ||
        (domainValue.length() > fnosSuffix.length() &&
         domainValue.compare(
             domainValue.length() - fnosSuffix.length(),
             fnosSuffix.length(),
             fnosSuffix) == 0);
    if (isFnosDomain) {
        // fnOS hands these cookies across the fnos.net / <fnid>.fnos.net
        // redirect chain. Match the browser cookie attributes instead of
        // leaving WebView2's default Lax/insecure session attributes.
        cookie->put_IsSecure(TRUE);
        cookie->put_SameSite(COREWEBVIEW2_COOKIE_SAME_SITE_KIND_NONE);
    }

    const auto addHr = cookieManager->AddOrUpdateCookie(cookie.get());
    if (SUCCEEDED(addHr)) {
        const std::wstring cookieUri =
            L"https://" + std::wstring(domain == nullptr ? L"" : domain) +
            L"/";
        cookieManager->GetCookies(
            cookieUri.c_str(),
            Callback<ICoreWebView2GetCookiesCompletedHandler>(
                [](HRESULT result, ICoreWebView2CookieList* cookieList)
                    -> HRESULT {
                  UINT count = 0;
                  if (SUCCEEDED(result) && cookieList != nullptr) {
                    cookieList->get_Count(&count);
                  }
                  std::cout << "[webview_win_floating] cookie manager verify"
                            << " hr=" << result << " count=" << count
                            << std::endl;
                  return S_OK;
                })
                .Get());
    }
    return addHr;
}

HRESULT MyWebViewImpl::suspend()
{
    auto webview2_3 = m_pWebview.try_query<ICoreWebView2_3>();
    if (webview2_3 == NULL) return E_FAIL;
    return webview2_3->TrySuspend(Callback<ICoreWebView2TrySuspendCompletedHandler>(
        [=](HRESULT errorCode, BOOL isSuccessful) -> HRESULT {
            return S_OK;
        }).Get());
}

HRESULT MyWebViewImpl::resume()
{
    auto webview2_3 = m_pWebview.try_query<ICoreWebView2_3>();
    if (webview2_3 == NULL) return E_FAIL;
    return webview2_3->Resume();
}

void MyWebViewImpl::openDevTools()
{
    m_pWebview->OpenDevToolsWindow();
}
