import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/utils/external_links.dart';

void main() {
  test('localizes the official website and document routes', () {
    expect(localizedTingReaderWebsiteUrl('zh'), tingReaderWebsiteUrl);
    expect(localizedTingReaderWebsiteUrl('en-US'), '$tingReaderWebsiteUrl/en');
    expect(
      localizedUserAgreementUrl('en'),
      '$tingReaderWebsiteUrl/about/user-agreement/en',
    );
    expect(
      localizedPrivacyPolicyUrl('en'),
      '$tingReaderWebsiteUrl/about/privacy-policy/en',
    );
    expect(
      localizedChangelogUrl('en'),
      '$tingReaderWebsiteUrl/about/changelog/en',
    );
    expect(
      localizedServerUpdateGuideUrl('en'),
      '$tingReaderWebsiteUrl/guide/update/en',
    );
    expect(
      localizedDownloadPageUrl('en'),
      '$tingReaderWebsiteUrl/en#download',
    );
  });
}
