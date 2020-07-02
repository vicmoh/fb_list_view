import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as _fs;
import 'package:firebase_database/firebase_database.dart' as _db;
import 'package:provider_skeleton/provider_skeleton.dart';

import './fb_list_view_logic.dart';

/// The list view type that can be used.
enum _Type { realtimeDatabase, cloudFirestore }

/// Schmick list view containing the smart
/// refresher where you can refresh the page.
class FBListView<T extends Model> extends StatefulWidget {
/* ----------------------------- Widget setting ----------------------------- */
  /// Widget of when the list is empty.
  /// This widget is placed outside the widget
  /// in  comparison to [onEmptyList].
  final Widget onEmptyWidget;

  /// Widget of when the list is empty.
  /// This widget will be placed inside the list view
  /// in comparison to [onEmptyWidget]
  final Widget onEmptyList;

  /// The widget builder of each tile in the list.
  /// The builder callbacks the index and the model.
  final Widget Function(List<T>, int) builder;

  /// Determine is the list view is reverse.
  final bool isReverse;

  /// Inner padding of the list view.
  final EdgeInsetsGeometry padding;

  /// Loader.
  final Widget loaderWidget;

  /// Determine whether to always show
  /// [loaderWidget] on refresh.
  /// If false, it will only show
  /// the loader at the start.
  final bool alwaysShowLoader;

  /// The list view scroll controller.
  final ScrollController controller;

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
  final Function(Future<void> Function()) refresher;

  /// The header widget when refreshing.
  final Widget headerWidget;

  /// The footer widget when on paginate load.
  final Widget footerWidget;

  /// Create with sliver list. Callback the
  /// the sliver widget list version.
  /// This callback must return list of sliver widgets.
  final List<Widget> Function(Widget sliverList) slivers;

  /// Function callback to determine if the logic
  /// is currently fetching.
  /// Callback false if fetching, and true if complete.
  final Function(bool) onFirstFetchStatus;

  /* ---------------------------------- Logic --------------------------------- */

  /// The list view type.
  final _Type _type;

  /// Compare function to order the list.
  final int Function(T, T) orderBy;

  /// On error on fetching, all catches
  /// when fetching will be on this callback.
  final Function(dynamic) onFetchCatch;

  /* -------------------------------- Firestore ------------------------------- */

  /// Firestore query.
  final _fs.Query fsQuery;

  /// When snap is received. For each data
  /// that that has been received should convert the
  /// snapshot into an object.
  final Future<T> Function(_fs.DocumentSnapshot) forEachSnap;

  /* -------------------------------- Firebase -------------------------------- */

  /// Query for the list view, you can
  /// also used reference.
  final _db.Query dbQuery;

  /// You can use database reference where
  /// it will will create query limit of 30
  /// based on recent timestamp. If you want
  /// a manual query use [dbQuery]. If [dbQuery]
  /// exist it will use that instead. If this
  /// is not null it will to listen new
  /// data.
  final _db.DatabaseReference dbReference;

  /// When snap is received. For each data
  /// that that has been received should convert the
  /// snapshot into an object.
  final Future<T> Function(String id, Map<String, dynamic> json) forEachJson;

  /* ------------------------------- Constructor ------------------------------ */

  /// List view for Firestore.
  FBListView.cloudFirestore({
    @required this.fsQuery,
    @required this.builder,
    @required this.forEachSnap,
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
  })  : _type = _Type.cloudFirestore,
        assert(!(builder == null)),
        assert(fsQuery != null),
        assert(forEachSnap != null),
        this.dbQuery = null,
        this.forEachJson = null,
        this.dbReference = null;

  /// List view for Firebase DB
  FBListView.realtimeDatabase({
    @required this.builder,
    @required this.forEachJson,
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
  })  : assert(!(dbQuery == null && dbReference == null)),
        assert(!(builder == null)),
        assert(forEachJson != null),
        _type = _Type.realtimeDatabase,
        this.fsQuery = null,
        this.forEachSnap = null;

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
  FBListViewLogic _logic;
  bool _isFirstTimeLoading = true;

  @override
  void initState() {
    super.initState();
    this.widget.padding ?? EdgeInsets.all(0);

    /// Determine which logic it will be using.
    _isFirstTimeLoading = true;
    if (this.widget._type == _Type.cloudFirestore)
      _logic = FBListViewLogic<T>.cloudFirestore(
          onFirstFetchStatus: (status) {
                setState(() => _isFirstTimeLoading = !status);
                if (this.widget.onFirstFetchStatus != null)
                  this.widget.onFirstFetchStatus(status);
              },
          fsQuery: this.widget.fsQuery,
          forEachSnap: this.widget.forEachSnap,
          fetchDelay: this.widget.fetchDelay,
          onFetchCatch: this.widget.onFetchCatch,
          orderBy: this.widget.orderBy,
          refresher: this.widget.refresher);
    else if (this.widget._type == _Type.realtimeDatabase)
      _logic = FBListViewLogic<T>.realtimeDatabase(
          onFirstFetchStatus: (status) {
                setState(() => _isFirstTimeLoading = !status); 
                if (this.widget.onFirstFetchStatus != null)
                  this.widget.onFirstFetchStatus(status);
              },
          dbReference: this.widget.dbReference,
          dbQuery: this.widget.dbQuery,
          forEachJson: this.widget.forEachJson,
          fetchDelay: this.widget.fetchDelay,
          onFetchCatch: this.widget.onFetchCatch,
          orderBy: this.widget.orderBy,
          refresher: this.widget.refresher);
  }

  @override
  Widget build(BuildContext context) => _smartRefresher();

  _listView(FBListViewLogic model) {
    var isEmptyWidget =
        this.widget.onEmptyWidget != null && model.items.isEmpty;
    if (isEmptyWidget && model.isLoading)
      return this.widget.loaderWidget ?? Container();
    if (isEmptyWidget || this.widget.debugEmptyWidget)
      return this.widget.onEmptyWidget ?? Container();
    return SmartRefresher(
        reverse: this.widget.isReverse,
        controller: model.refreshController,
        enablePullDown: this.widget.isReverse ? false : true,
        enablePullUp: true,
        header: this.widget.headerWidget ?? FBListView.waterDropHeader(),
        footer: this.widget.footerWidget ?? FBListView.emptyFooter(),
        onRefresh: () => model.onRefresh(),
        onLoading: () => model.onLoading(),
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: _listViewContent(model.items, isLoading: model.isLoading));
  }

  _smartRefresher() => Container(
      child: WatchState<FBListViewLogic>(
          logic: _logic, builder: (model) => _listView(model)));

  _sliver(List<Widget> child) => CustomScrollView(
      controller: this.widget.controller,
      physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: child);

  _sliverList(List<Model> items) => SliverPadding(
      padding: this.widget.padding,
      sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  this.widget.builder(List.castFrom<Model, T>(items), index),
              childCount: items.length)));

  _listViewBuilder(List<Model> items) => ListView.builder(
      physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      controller: this.widget.controller,
      padding: this.widget.padding,
      itemCount: items.length,
      itemBuilder: (context, index) =>
          this.widget.builder(List.castFrom<Model, T>(items), index));

  _listViewContent(List<Model> items, {@required bool isLoading}) {
    if ((this.widget.loaderWidget != null &&
            this.widget.alwaysShowLoader &&
            isLoading) ||
        _isFirstTimeLoading) return this.widget.loaderWidget ?? Container();
    if (this.widget.debugEmptyList) return this.widget.onEmptyList;
    if (items.length == 0) return this.widget.onEmptyList ?? Container();
    if (this.widget.slivers != null)
      return _sliver(this.widget.slivers(_sliverList(items)));
    return _listViewBuilder(items);
  }
}
