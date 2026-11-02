#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlMethodChannel* window_channel;
  gchar* close_behavior;
  gboolean mini_mode;
  gint normal_width;
  gint normal_height;
  gint normal_x;
  gint normal_y;
  gboolean normal_maximized;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void set_mini_mode(MyApplication* self, gboolean enabled) {
  if (self->mini_mode == enabled) return;
  self->mini_mode = enabled;
  if (enabled) {
    gtk_window_get_size(self->window, &self->normal_width, &self->normal_height);
    gtk_window_get_position(self->window, &self->normal_x, &self->normal_y);
    self->normal_maximized = gtk_window_is_maximized(self->window);
    gtk_window_unmaximize(self->window);
    gtk_window_resize(self->window, 560, 174);
  } else {
    gtk_window_resize(self->window, self->normal_width, self->normal_height);
    gtk_window_move(self->window, self->normal_x, self->normal_y);
    if (self->normal_maximized) gtk_window_maximize(self->window);
  }
  gtk_window_set_keep_above(self->window, enabled);
  g_autoptr(FlValue) value = fl_value_new_bool(enabled);
  fl_method_channel_invoke_method(self->window_channel, "miniModeChanged",
                                 value, nullptr, nullptr, nullptr);
}

static gboolean handle_window_state(GtkWidget*, GdkEventWindowState* event, gpointer data) {
  MyApplication* self = MY_APPLICATION(data);
  const gboolean maximized = (event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) != 0;
  if (self->mini_mode && maximized) {
    set_mini_mode(self, FALSE);
    gtk_window_maximize(self->window);
  }
  if (event->changed_mask & GDK_WINDOW_STATE_MAXIMIZED) {
    g_autoptr(FlValue) value = fl_value_new_bool(maximized);
    fl_method_channel_invoke_method(self->window_channel, "maximizedChanged",
                                   value, nullptr, nullptr, nullptr);
  }
  return FALSE;
}

static gboolean handle_window_close(GtkWidget*, GdkEvent*, gpointer data) {
  MyApplication* self = MY_APPLICATION(data);
  if (g_strcmp0(self->close_behavior, "exit") == 0) {
    g_application_quit(G_APPLICATION(self));
  } else if (g_strcmp0(self->close_behavior, "minimize") == 0) {
    gtk_window_iconify(self->window);
  } else {
    fl_method_channel_invoke_method(self->window_channel, "closeRequested",
                                   nullptr, nullptr, nullptr, nullptr);
  }
  return TRUE;
}

static void handle_window_method(FlMethodChannel*, FlMethodCall* call,
                                 gpointer data) {
  MyApplication* self = MY_APPLICATION(data);
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  g_autoptr(FlValue) value = nullptr;
  if (g_strcmp0(method, "setMiniMode") == 0) {
    const gboolean enabled = args && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL &&
                             fl_value_get_bool(args);
    set_mini_mode(self, enabled);
  } else if (g_strcmp0(method, "setCloseBehavior") == 0) {
    g_free(self->close_behavior);
    self->close_behavior = g_strdup(args && fl_value_get_type(args) == FL_VALUE_TYPE_STRING
        ? fl_value_get_string(args) : "ask");
  } else if (g_strcmp0(method, "minimize") == 0) {
    gtk_window_iconify(self->window);
  } else if (g_strcmp0(method, "close") == 0) {
    gtk_window_close(self->window);
  } else if (g_strcmp0(method, "exit") == 0) {
    g_application_quit(G_APPLICATION(self));
  } else if (g_strcmp0(method, "toggleMaximize") == 0) {
    const gboolean force = args && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL && fl_value_get_bool(args);
    const gboolean maximize = self->mini_mode || force || !gtk_window_is_maximized(self->window);
    if (self->mini_mode) set_mini_mode(self, FALSE);
    if (maximize) gtk_window_maximize(self->window);
    else gtk_window_unmaximize(self->window);
    value = fl_value_new_bool(maximize);
  } else if (g_strcmp0(method, "startDragging") == 0) {
    GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(self->window));
    GdkDevice* pointer = gdk_seat_get_pointer(gdk_display_get_default_seat(display));
    gint x = 0;
    gint y = 0;
    gdk_device_get_position(pointer, nullptr, &x, &y);
    gtk_window_begin_move_drag(self->window, 1, x, y, gtk_get_current_event_time());
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  fl_method_call_respond_success(call, value, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "听悦");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
  gtk_window_set_title(window, "听悦");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "ting_reader/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel,
                                          handle_window_method, self, nullptr);
  g_signal_connect(window, "delete-event", G_CALLBACK(handle_window_close), self);
  g_signal_connect(window, "window-state-event", G_CALLBACK(handle_window_state), self);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  g_clear_pointer(&self->close_behavior, g_free);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->close_behavior = g_strdup("exit");
}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
