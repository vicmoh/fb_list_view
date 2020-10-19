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
      ref: v0.0.14

  #------------------------------------------------------
  # below are package dependencies that FBListView needs.
  #------------------------------------------------------

  provider_skeleton:
    git:
      url: git://github.com/vicmoh/provider_skeleton.git
      ref: v0.0.17 # this version or higher.

  dart_util:
    git:
      url: git://github.com/vicmoh/dart_util.git
      ref: v0.0.9 # this version or higher.

  # Widget for pagination.
  pull_to_refresh: ^1.5.8

  # Firebase
  firebase_auth: ^0.15.3+1
  firebase_database: ^3.1.1
  firebase_core: ^0.4.3+3
  firebase_messaging: ^6.0.9
  cloud_firestore: ^0.13.0+1
  firebase_storage: ^3.1.1
```


