# About

Firebase list view widget that will
paginate and manage the list for you.

# Installation

In `pubspec.yaml` import the dependency.
This widget is dependent on `provider_skeleton`
and `dart_util`. Copy paste the below:

```
dependencies:
  flutter:
    sdk: flutter

  fb_list_view:
    git:
      url: git://github.com/vicmoh/fb_list_view.git
      ref: v0.0.21

  #------------------------------------------------------
  # below are package dependencies that FBListView needs.
  #------------------------------------------------------

  # Dependencies
  provider_skeleton:
    git:
      url: git://github.com/vicmoh/provider_skeleton.git
      ref: v0.0.24

  dart_util:
    git:
      url: git://github.com/vicmoh/dart_util.git
      ref: v0.0.13

  # Widget for pagination
  pull_to_refresh: ^2.0.0
  infinite_scroll_pagination: ^3.1.0

  # Firebase
  firebase_auth: ^3.1.3
  firebase_database: ^8.0.0
  firebase_core: ^1.7.0
  firebase_messaging: ^10.0.8
  cloud_firestore: ^2.5.3
  firebase_storage: ^10.0.5
```
