import 'dart:async';
import 'package:meta/meta.dart';
import 'package:provider_skeleton/provider_skeleton.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as _fs;
import 'package:firebase_database/firebase_database.dart' as _db;
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:dart_util/dart_util.dart';

/// Firebase type.
enum FBTypes {
  /// Firebase realtime database type.
  realtimeDatabase,

  /// Cloud Firestore type.
  cloudFirestore
}

/// View logic for managing list Firebase fetches and pagination.
class FBListViewLogic<T extends Model> extends ViewLogic
    with UniquifyListModel<T> {
  /* ---------------------------------- Logic --------------------------------- */

  /// The list view type.
  final FBTypes _type;

  /// Compare function to order the list.
  final int Function(T, T) orderBy;

  /// On error on fetching, all catches
  /// when fetching will be on this callback.
  final Function(dynamic) onFetchCatch;

  /// Function callback to determine if the logic
  /// is currently fetching.
  /// Callback false if fetching, and true if complete.
  final Function(bool) onFirstFetchStatus;

  /// Fetch delay on initialize state in milliseconds.
  final int fetchDelay;

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

  /// A call back that will the function to
  /// refresh the page.
  final Function(Future<void> Function()) refresher;

  /* ------------------------------- Constructor ------------------------------ */

  /// List view for Firestore.
  FBListViewLogic.cloudFirestore({
    @required this.fsQuery,
    @required this.forEachSnap,
    this.onFetchCatch,
    this.orderBy,
    this.fetchDelay = 0,
    this.refresher,
    this.onFirstFetchStatus,
  })  : _type = FBTypes.cloudFirestore,
        assert(fsQuery != null),
        assert(forEachSnap != null),
        this.dbQuery = null,
        this.forEachJson = null,
        this.dbReference = null;

  /// List view for Firebase DB
  FBListViewLogic.realtimeDatabase({
    @required this.forEachJson,
    this.dbQuery,
    this.dbReference,
    this.orderBy,
    this.onFetchCatch,
    this.fetchDelay = 0,
    this.refresher,
    this.onFirstFetchStatus,
  })  : assert(!(dbQuery == null && dbReference == null)),
        assert(forEachJson != null),
        _type = FBTypes.realtimeDatabase,
        this.fsQuery = null,
        this.forEachSnap = null;

  /* -------------------------------- Lifecycle ------------------------------- */

  @override
  void initState() {
    super.initState();
    _status(false);
    _refreshController = RefreshController();

    /// Set status as loading.
    refresh(ViewState.asLoading);
    Future.microtask(
        () => Future.delayed(Duration(milliseconds: fetchDelay)).then((_) {
              if (_type == FBTypes.cloudFirestore)
                this._cloudFirestoreListen().then((_) => _status(true));
              else if (_type == FBTypes.realtimeDatabase)
                this.onRefresh().then((_) {
                  _status(true);
                  _realtimeDatabaseListen();
                });
            })).catchError((err) {
      refresh(ViewState.asError);
      onFetchCatch(err);
    });

    /// Callback refresher
    if (refresher != null) refresher(this.onRefresh);
  }

  @override
  void dispose() {
    _cloudFirestoreSubscription?.cancel();
    _realtimeDatabaseSubscriptionOnAdded?.cancel();
    _realtimeDatabaseSubscriptionOnChanged?.cancel();
    _refreshController?.dispose();
    super.dispose();
  }

  /* -------------------------------------------------------------------------- */
  /*                              Private variable                              */
  /* -------------------------------------------------------------------------- */

  /// The refresh controller for smart refresher.
  get refreshController => _refreshController;
  RefreshController _refreshController;

  // Keep track of snaps and subs
  _fs.DocumentSnapshot _lastSnap;
  StreamSubscription _cloudFirestoreSubscription;
  StreamSubscription _realtimeDatabaseSubscriptionOnAdded;
  StreamSubscription _realtimeDatabaseSubscriptionOnChanged;

  /* -------------------------------------------------------------------------- */
  /*                                  Functions                                 */
  /* -------------------------------------------------------------------------- */

  ///The default limit value.
  static const DEFAULT_LIMIT = 30;

  void _status(bool val) =>
      this.onFirstFetchStatus == null ? null : this.onFirstFetchStatus(val);

  /// On First time load.
  Future<void> onRefresh() async {
    refresh(ViewState.asLoading);
    if (_type == FBTypes.cloudFirestore)
      replaceItems(await _firestoreFetch());
    else if (_type == FBTypes.realtimeDatabase)
      replaceItems(await _realtimeDatabaseFetch());
    if (orderBy != null) getItems<T>().sort(orderBy);
    _refreshController?.refreshToIdle();
    refresh(ViewState.asComplete);
  }

  /// Load next pagination.
  /// This is usually assigned on the
  /// SmartRefresher onLoading.
  Future<void> onLoading() async {
    if (_type == FBTypes.cloudFirestore)
      addItems(await _firestoreFetch(isNext: true));
    else if (_type == FBTypes.realtimeDatabase)
      addItems(await _realtimeDatabaseFetch(isNext: true));
    if (orderBy != null) items.sort(orderBy);
    _refreshController?.loadComplete();
    refresh(ViewState.asComplete);
  }

  Future<void> _updateRealtimeData(event) async {
    try {
      addItems([
        await forEachJson(event?.snapshot?.key,
            Map<String, dynamic>.from(event?.snapshot?.value ?? {})),
      ]);
    } catch (err) {
      _printErr(err, isItem: true);
    }
    if (orderBy != null) getItems<T>().sort(orderBy);
    refresh(ViewState.asComplete);
  }

  Future<void> _realtimeDatabaseListen() async {
    /// On child updated
    _realtimeDatabaseSubscriptionOnAdded =
        dbReference?.limitToLast(1)?.onChildAdded?.listen((event) async {
      await _updateRealtimeData(event);
    });

    /// On child changes
    _realtimeDatabaseSubscriptionOnChanged =
        dbReference?.limitToLast(1)?.onChildChanged?.listen((event) async {
      await _updateRealtimeData(event);
    });
  }

  Future<void> _cloudFirestoreListen() async {
    _cloudFirestoreSubscription = fsQuery?.snapshots()?.listen((data) async {
      try {
        addItems(List<T>.from(
            await Future.wait<T>(data.documentChanges.map((docChange) async {
              try {
                return await forEachSnap(docChange.document);
              } catch (err) {
                _printErr(err, isItem: true);
                return null;
              }
            })),
            growable: true));
        _lastSnap = data.documentChanges.last.document;
        _status(true);
        if (orderBy != null) getItems<T>().sort(orderBy);
        refresh(ViewState.asComplete);
      } catch (err) {
        _printErr(err, isItem: false);
      }
    });
  }

  Future<List<T>> _realtimeDatabaseFetch({bool isNext = false}) async {
    List<T> data = [];
    try {
      var query =
          dbQuery ?? dbReference.orderByKey().limitToLast(DEFAULT_LIMIT);
      if (isNext) query = query.endAt(getItems<T>().last.id);
      var snap = await query.once();
      var jsonObj = Map<String, dynamic>.from(snap.value ?? {});
      data = await Future.wait<T>(jsonObj.entries.toList().map((each) async {
        try {
          return await forEachJson(
              each.key, Map<String, dynamic>.from(each.value ?? {}));
        } catch (err) {
          _printErr(err, isItem: true);
          return null;
        }
      }));
    } catch (err) {
      if (isNext) _refreshController?.loadNoData();
      if (onFetchCatch != null) onFetchCatch(err);
      _printErr(err);
    }
    return data;
  }

  Future<List<T>> _firestoreFetch({bool isNext = false}) async {
    List<T> data = [];
    try {
      var query = fsQuery;
      if (isNext && _lastSnap != null)
        query = query.startAfterDocument(_lastSnap);
      var doc = await query.getDocuments();
      _lastSnap = doc.documents.last;
      data = await Future.wait<T>(doc?.documents?.map((snap) async {
        try {
          return await forEachSnap(snap);
        } catch (err) {
          _printErr(err, isItem: true);
          return null;
        }
      }));
    } catch (err) {
      if (isNext) _refreshController?.loadNoData();
      if (onFetchCatch != null) onFetchCatch(err);
      _printErr(err);
    }
    return data;
  }

  _printErr(err, {bool isItem = false}) {
    if (err == null) return;
    var message = isItem ? 'item' : 'list';
    Result.hasError(
        clientMessage: 'Could not fetch $message.',
        errorType: ErrorTypes.server,
        devMessage: Log.asString(
            this, 'Could not get $message. Returning empty. Err -> $err'));
  }
}
