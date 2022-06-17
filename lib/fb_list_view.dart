/// Export libraries.
export 'package:fb_list_view/fb_list_view_logic.dart';

/// Import libraries.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as _fs;
import 'package:firebase_database/firebase_database.dart' as _db;
import 'package:provider_skeleton/provider_skeleton.dart';
import 'package:fb_list_view/fb_list_view_logic.dart';

/// The list view type that can be used.
enum _Type { realtimeDatabase, cloudFirestore }

/// Schmick list view containing the smart
/// refresher where you can refresh the page.
class FBListView<T extends Model> extends StatefulWidget {
  /* ----------------------------- Widget setting ----------------------------- */

  /// Sort based on [orderBy] after items are added.
  final bool presortOnItemsAdded;

  /// With this is true, all new data
  /// that is streamed and listened from
  /// the database not be added to the item list.
  /// You can use the [fsListen] or [dbListen]
  /// to get the item.
  final bool withoutNewItemsToList;

  /// Get Firebase list view logic from callback.
  final Function(FBListViewLogic<T>?)? getLogic;

  /// Widget of when the list is empty.
  /// This widget is placed outside the widget
  /// in  comparison to [onEmptyList].
  final Widget? onEmptyWidget;

  /// Widget of when the list is empty.
  /// This widget will be placed inside the list view
  /// in comparison to [onEmptyWidget]
  final Widget? onEmptyList;

  /// The widget builder of each tile in the list.
  /// The builder callbacks the index and the model.
  final Widget Function(List<T>, int) builder;

  /// Determine is the list view is reverse.
  final bool isReverse;

  /// Inner padding of the list view.
  final EdgeInsetsGeometry? padding;

  /// Loader.
  final Widget? loaderWidget;

  /// Determine whether to always show
  /// [loaderWidget] on refresh.
  /// If false, it will only show
  /// the loader at the start.
  final bool alwaysShowLoader;

  /// The list view scroll controller.
  final ScrollController? controller;

  /// Fetch delay on initialize state in milliseconds.
  final int fetchDelay;

  /// If this set to true, it will show the empty list.
  /// This is meant for debugging purposes
  /// This is for debugging for [onEmptyList].
  final bool debugEmptyList;

  /// If this set to true, it will show the empty list.
  /// This is meant for debugging purposes.
  /// This is for debugging for [onEmptyWidget]
  final bool debugEmptyWidget;

  /// A call back that will the function to
  /// refresh the page.
  final Function(Future<void> Function())? refresher;

  /// The header widget when refreshing.
  final Widget? headerWidget;

  /// The footer widget when on paginate load.
  final Widget? footerWidget;

  /// Create with sliver list. Callback the
  /// the sliver widget list version.
  /// This callback must return list of sliver widgets.
  final List<Widget> Function(Widget sliverList)? slivers;

  /// Function callback to determine if the logic
  /// is currently fetching.
  /// Callback false if fetching, and true if complete.
  final Function(bool)? onFirstFetchStatus;

  /// On first fetch error catch.
  final Function(dynamic)? onFirstFetchCatch;

  /// The scroll physics of the list view.
  final ScrollPhysics? scrollPhysics;

  /// The viewport at which the widget will be cached.
  final double cacheExtent;

  /// Determine to disable loader widget if
  /// items exist. Useful for showing cached items
  /// instead of a loader on first initialization.
  final bool skipLoaderIfItemExist;

  /* ---------------------------------- Logic --------------------------------- */

  /// Disable the usage of concurrent fetch.
  final bool disableConcurrentFetch;

  /// Disable live stream of new items.
  final bool disableListener;

  /// The list view type.
  final _Type _type;

  /// Compare function to order the list.
  final int Function(T?, T?)? orderBy;

  /// On error on fetching, all catches
  /// when fetching will be on this callback.
  final Function(dynamic)? onFetchCatch;

  /* -------------------------------- Firestore ------------------------------- */

  /// Listen to new data on Firestore.
  final Future<void> Function(FBListViewLogic<T>, _fs.QuerySnapshot)? fsListen;

  /// Firestore query.
  final _fs.Query<Object>? fsQuery;

  /// When snap is received. For each data
  /// that that has been received should convert the
  /// snapshot into an object.
  final Future<T?> Function(_fs.DocumentSnapshot)? forEachSnap;

  /* -------------------------------- Firebase -------------------------------- */

  /// Listen to new data on Firebase database.
  final Future<void> Function(FBListViewLogic<T>, _db.Event)? dbListen;

  /// Used for pagination. For example when
  /// ordering by timestamp in firebase real time
  /// The startAt and endAt value must be the value
  /// in which you are ordering.
  ///
  /// Example:
  /// ```
  /// onNextQuery: (query, items) =>
  ///             query.endAt(items.last.timestamp.millisecondsSinceEpoch - 1)
  /// ```
  final _db.Query Function(_db.Query, List<T?> items)? onNextQuery;

  /// Query for the list view, you can
  /// also used reference.
  final _db.Query? dbQuery;

  /// You can use database reference where
  /// it will will create query limit of 30
  /// based on recent timestamp. If you want
  /// a manual query use [dbQuery]. If [dbQuery]
  /// exist it will use that instead. If this
  /// is not null it will to listen new
  /// data.
  final _db.DatabaseReference? dbReference;

  /// When snap is received. For each data
  /// that that has been received should convert the
  /// snapshot into an object.
  final Future<T?> Function(String? id, Map<String, dynamic> json)? forEachJson;

  /* ------------------------------- Constructor ------------------------------ */

  /// List view for Firestore.
  FBListView.cloudFirestore({
    required _fs.Query<Object> this.fsQuery,
    required this.builder,
    required this.forEachSnap,
    this.onFetchCatch,
    this.orderBy,
    this.onEmptyWidget,
    this.onEmptyList,
    this.loaderWidget,
    this.padding,
    this.controller,
    this.isReverse = false,
    this.fetchDelay = 0,
    this.debugEmptyWidget = false,
    this.debugEmptyList = false,
    this.refresher,
    this.headerWidget,
    this.footerWidget,
    this.slivers,
    this.alwaysShowLoader = false,
    this.onFirstFetchStatus,
    this.scrollPhysics,
    this.cacheExtent = 0,
    this.getLogic,
    this.disableListener = false,
    this.onFirstFetchCatch,
    this.fsListen,
    this.withoutNewItemsToList = false,
    this.presortOnItemsAdded = false,
    this.disableConcurrentFetch = false,
    this.skipLoaderIfItemExist = false,
  })  : _type = _Type.cloudFirestore,
        assert(forEachSnap != null),
        this.dbQuery = null,
        this.forEachJson = null,
        this.dbReference = null,
        this.onNextQuery = null,
        this.dbListen = null;

  /// List view for Firebase DB
  FBListView.realtimeDatabase({
    required this.builder,
    required this.forEachJson,
    this.dbQuery,
    this.dbReference,
    this.onEmptyWidget,
    this.onEmptyList,
    this.orderBy,
    this.loaderWidget,
    this.padding,
    this.controller,
    this.isReverse = false,
    this.fetchDelay = 0,
    this.debugEmptyWidget = false,
    this.debugEmptyList = false,
    this.onFetchCatch,
    this.refresher,
    this.headerWidget,
    this.footerWidget,
    this.slivers,
    this.alwaysShowLoader = false,
    this.onFirstFetchStatus,
    this.scrollPhysics,
    this.cacheExtent = 0,
    this.onNextQuery,
    this.getLogic,
    this.disableListener = false,
    this.onFirstFetchCatch,
    this.dbListen,
    this.withoutNewItemsToList = false,
    this.presortOnItemsAdded = false,
    this.disableConcurrentFetch = false,
    this.skipLoaderIfItemExist = false,
  })  : assert(!(dbQuery == null && dbReference == null)),
        assert(forEachJson != null),
        _type = _Type.realtimeDatabase,
        this.fsQuery = null,
        this.forEachSnap = null,
        this.fsListen = null;

  /// Water drop material header with
  /// the sliver.
  static Widget waterDropMaterialHeader({
    Color color = Colors.black,
    Color backgroundColor = Colors.white,
  }) =>
      WaterDropMaterialHeader(backgroundColor: backgroundColor, color: color);

  /// The header of when refreshing a page.
  static Widget waterDropHeader({
    Color color = Colors.black,
    Color backgroundColor = Colors.white,
  }) =>
      WaterDropHeader(
          waterDropColor: backgroundColor,
          idleIcon: Icon(Icons.autorenew, size: 15, color: color));

  /// The footer of when paginating to the next page.
  static Widget emptyFooter() => CustomFooter(builder: (context, status) {
        if (status == LoadStatus.loading)
          return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(child: CircularProgressIndicator())
              ]);
        return Container();
      });

  @override
  _FBListViewState<T> createState() => _FBListViewState<T>();
}

class _FBListViewState<T extends Model> extends State<FBListView<T>> {
  FBListViewLogic<T>? _logic;
  bool _isFirstTimeLoading = true;

  @override
  void dispose() {
    _logic?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    this.widget.padding ?? EdgeInsets.all(0);

    /// Determine which logic it will be using.
    _isFirstTimeLoading = true;
    if (this.widget._type == _Type.cloudFirestore)
      _logic = FBListViewLogic<T>.cloudFirestore(
          disableConcurrentFetch: widget.disableConcurrentFetch,
          presortOnItemsAdded: widget.presortOnItemsAdded,
          withoutNewItemsToList: widget.withoutNewItemsToList,
          fsListen: widget.fsListen,
          onFirstFetchCatch: widget.onFirstFetchCatch,
          disableListener: widget.disableListener,
          onFirstFetchStatus: (status) {
            setState(() => _isFirstTimeLoading = !status);
            if (this.widget.onFirstFetchStatus != null)
              this.widget.onFirstFetchStatus!(status);
          },
          fsQuery: this.widget.fsQuery!,
          forEachSnap: this.widget.forEachSnap!,
          fetchDelay: this.widget.fetchDelay,
          onFetchCatch: this.widget.onFetchCatch,
          orderBy: this.widget.orderBy,
          refresher: this.widget.refresher);
    else if (this.widget._type == _Type.realtimeDatabase)
      _logic = FBListViewLogic<T>.realtimeDatabase(
          disableConcurrentFetch: widget.disableConcurrentFetch,
          presortOnItemsAdded: widget.presortOnItemsAdded,
          withoutNewItemsToList: widget.withoutNewItemsToList,
          dbListen: widget.dbListen,
          onFirstFetchCatch: widget.onFirstFetchCatch,
          disableListener: widget.disableListener,
          onNextQuery: this.widget.onNextQuery,
          onFirstFetchStatus: (status) {
            setState(() => _isFirstTimeLoading = !status);
            if (this.widget.onFirstFetchStatus != null)
              this.widget.onFirstFetchStatus!(status);
          },
          dbReference: this.widget.dbReference,
          dbQuery: this.widget.dbQuery,
          forEachJson: this.widget.forEachJson!,
          fetchDelay: this.widget.fetchDelay,
          onFetchCatch: this.widget.onFetchCatch,
          orderBy: this.widget.orderBy,
          refresher: this.widget.refresher);

    if (widget.getLogic != null) widget.getLogic!(_logic);
  }

  @override
  Widget build(BuildContext context) => _smartRefresher();

  _listView(FBListViewLogic<T> model) {
    var isEmptyWidget =
        this.widget.onEmptyWidget != null && model.items.isEmpty;
    if (isEmptyWidget && model.isLoading)
      return this.widget.loaderWidget ?? Container();
    if (isEmptyWidget || this.widget.debugEmptyWidget)
      return this.widget.onEmptyWidget ?? Container();
    return SmartRefresher(
        reverse: this.widget.isReverse,
        controller: model.refreshController!,
        enablePullDown: this.widget.isReverse ? false : true,
        enablePullUp: true,
        cacheExtent: widget.cacheExtent,
        header: this.widget.headerWidget,
        footer: this.widget.footerWidget ?? FBListView.emptyFooter(),
        onRefresh: () => model.onRefresh(),
        onLoading: () => model.onLoading(),
        physics: widget.scrollPhysics,
        child: _listViewContent(model.items, isLoading: model.isLoading));
  }

  _smartRefresher() => Container(
      child: WatchState<FBListViewLogic<T>>(
          logic: _logic, builder: (model) => _listView(model)));

  _sliver(List<Widget> child) =>
      CustomScrollView(controller: this.widget.controller, slivers: child);

  _sliverList(List<T> items) => SliverPadding(
      padding: this.widget.padding!,
      sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
              (context, index) => this.widget.builder(items, index),
              childCount: items.length)));

  _listViewBuilder(List<T> items) => ListView.builder(
      physics: widget.scrollPhysics,
      controller: this.widget.controller,
      padding: this.widget.padding,
      itemCount: items.length,
      itemBuilder: (context, index) => this.widget.builder(items, index));

  _listViewContent(List<T> items, {required bool isLoading}) {
    if (!this.widget.skipLoaderIfItemExist &&
        items.length == 0 &&
        ((this.widget.loaderWidget != null &&
                this.widget.alwaysShowLoader &&
                isLoading) ||
            _isFirstTimeLoading))
      return this.widget.loaderWidget ?? Container();

    if (this.widget.debugEmptyList) return this.widget.onEmptyList;
    if (/*!this.widget.skipLoaderIfItemExist &&*/ items.length == 0 &&
        !isLoading) return this.widget.onEmptyList ?? Container();

    if (this.widget.slivers != null)
      return _sliver(this.widget.slivers!(_sliverList(items)));
    return _listViewBuilder(items);
  }
}
