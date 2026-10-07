#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"
#include "native_game.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Gives the window an icon of its own, taken from the bundle next to the
// binary.
//
// Without this the only icon a desktop can find is the one a desktop entry
// points at, which means nothing at all when the app runs from an AppImage or
// an unpacked archive that was never installed. The themed name is tried first
// so an installed copy keeps using the system icon.
static void my_application_set_window_icon(GtkWindow* window) {
  if (gtk_icon_theme_has_icon(gtk_icon_theme_get_default(), APPLICATION_ID)) {
    gtk_window_set_icon_name(window, APPLICATION_ID);
    return;
  }

  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable == nullptr) {
    return;
  }

  g_autofree gchar* bundle_dir = g_path_get_dirname(executable);
  g_autofree gchar* icon_path =
      g_build_filename(bundle_dir, "data", "flutter_assets", "assets", "icons",
                       "moonfin.png", nullptr);

  g_autoptr(GError) error = nullptr;
  g_autoptr(GdkPixbuf) icon = gdk_pixbuf_new_from_file(icon_path, &error);
  if (icon == nullptr) {
    g_warning("Could not load the window icon from %s: %s", icon_path,
              error->message);
    return;
  }

  gtk_window_set_icon(window, icon);
}

// Gives a Wayland compositor something to find when it looks up this window.
//
// A Wayland window carries no icon of its own, so the desktop resolves one by
// matching the window's app id against the installed desktop entries. An
// AppImage installs nothing, which leaves the taskbar with a placeholder no
// matter what the image contains. Writing an entry into the user's own data
// directory, pointing back at the running image, is the only thing that
// answers that lookup.
//
// This runs for AppImage only. Every other package installs its own entry, and
// a second copy here would shadow it and go stale.
static void my_application_install_desktop_entry() {
  const gchar* appimage = g_getenv("APPIMAGE");
  if (appimage == nullptr || *appimage == '\0') {
    return;
  }

  g_autofree gchar* applications_dir =
      g_build_filename(g_get_user_data_dir(), "applications", nullptr);
  g_autofree gchar* entry_path = g_build_filename(
      applications_dir, APPLICATION_ID ".desktop", nullptr);
  g_autofree gchar* entry = g_strdup_printf(
      "[Desktop Entry]\n"
      "Type=Application\n"
      "Name=Moonfin\n"
      "Comment=Jellyfin & Emby media client\n"
      "Exec=\"%s\" %%U\n"
      "Icon=%s\n"
      "Categories=AudioVideo;Video;\n"
      "Terminal=false\n"
      "StartupWMClass=%s\n",
      appimage, APPLICATION_ID, APPLICATION_ID);

  // Rewrite only when something changed, so moving the image updates the entry
  // while an ordinary launch touches nothing.
  g_autofree gchar* existing = nullptr;
  if (g_file_get_contents(entry_path, &existing, nullptr, nullptr) &&
      g_strcmp0(existing, entry) == 0) {
    return;
  }

  if (g_mkdir_with_parents(applications_dir, 0755) != 0) {
    return;
  }

  g_autoptr(GError) error = nullptr;
  if (!g_file_set_contents(entry_path, entry, -1, &error)) {
    g_warning("Could not write the desktop entry to %s: %s", entry_path,
              error->message);
    return;
  }

  g_autofree gchar* icons_dir =
      g_build_filename(g_get_user_data_dir(), "icons", "hicolor", "512x512",
                       "apps", nullptr);
  if (g_mkdir_with_parents(icons_dir, 0755) != 0) {
    return;
  }

  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable == nullptr) {
    return;
  }
  g_autofree gchar* bundle_dir = g_path_get_dirname(executable);
  g_autofree gchar* source_path =
      g_build_filename(bundle_dir, "data", "flutter_assets", "assets", "icons",
                       "moonfin.png", nullptr);
  g_autofree gchar* icon_path =
      g_build_filename(icons_dir, APPLICATION_ID ".png", nullptr);

  g_autoptr(GFile) source = g_file_new_for_path(source_path);
  g_autoptr(GFile) target = g_file_new_for_path(icon_path);
  g_autoptr(GError) copy_error = nullptr;
  g_file_copy(source, target, G_FILE_COPY_OVERWRITE, nullptr, nullptr, nullptr,
              &copy_error);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gtk_window_set_title(window, "Moonfin");
  my_application_install_desktop_entry();
  my_application_set_window_icon(window);

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  moonfin_game_register(fl_view_get_engine(view));

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

static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
