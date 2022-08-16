import 'dart:async';
import 'package:provider_skeleton/provider_skeleton.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as _fs;
import 'package:firebase_database/firebase_database.dart' as _db;
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:dart_util/dart_util.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

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

  /// Determine if it is a manual fetch.
  /// If this is true, you can call [initFetch]
  /// to fetch the first fetch.
  /// if this is false it will fetch on first instantiation
  /// of the logic.
  final bool isManualFetch;

  /// Sort based on [orderBy] after items are added.
  final bool presortOnItemsAdded;

  /// With this is true, all new data
  /// that is streamed and listened from
  /// the database not be added to the item list.
  /// You can use the [fsListen] or [dbListen]
  /// to get the item.
  final bool withoutNewItemsToList;

  /// Disable live stream of new items.
  final bool disableListener;

  /// The list view type.
  final FBTypes _type;

  /// Compare function to order the list.
  final int Function(T?, T?)? orderBy;

  /// On error on fetching, all catches
  /// when fetching will be on this callback.
  final Future<void> Function(dynamic)? onFetchCatch;

  /// On first fetch error catch.
  final Future<void> Function(dynamic)? onFirstFetchCatch;

  /// Function callback to determine if the logic
  /// is currently fetching.
  /// Callback false if fetching, and true if complete.
  final Future<void> Function(bool)? onFirstFetchStatus;

  /// Fetch delay on initialize state in milliseconds.
  final int fetchDelay;

  /// The number of items on first fetch.
  /// This is Firestore only.
  final int numberOfFirstFetch;

  /// Paginate 30 items.
  final int limitBy;

  /// Disable the usage of concurrent fetch.
  final bool disableConcurrentFetch;

  /// A function callback that pass parameter is first fetch.
  final Future<void> Function(bool isFirstFetch)? whenRefresh;

  /* -------------------------------- Firestore ------------------------------- */

  /// Listen to new data on Firestore.
  final Future<void> Function(FBListViewLogic<T>, _fs.QuerySnapshot)? fsListen;

  /// Firestore query.
  _fs.Query<Object?>? fsQuery;
  void setFsQuery(_fs.Query<Object?>? query) {
    assert(
        fsQuery != null,
        "fsQuery can only be re-initialize if you are using fsQuery in the first place." +
            " Check if you are using fsQuery when you are first initializing it.");
    if (query == null) return;
    this.fsQuery = query;
  }

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
  _db.Query? dbQuery;
  void setDbQuery(_db.Query? query) {
    assert(
        dbQuery != null,
        "dbQuery can only be re-initialize if you are using dbQuery in the first place." +
            " Check if you are using dbQuery when you are first initializing it.");
    if (query == null) return;
    this.dbQuery = query;
  }

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

  /// A call back that will the function to
  /// refresh the page.
  final Function(Future<void> Function())? refresher;

  /* ------------------------------- Constructor ------------------------------ */

  /// List view for Firestore.
  FBListViewLogic.cloudFirestore({
    required _fs.Query<Object> this.fsQuery,
    required this.forEachSnap,
    this.onFetchCatch,
    this.orderBy,
    this.fetchDelay = 0,
    this.refresher,
    this.onFirstFetchStatus,
    this.limitBy = 30,
    this.numberOfFirstFetch = 30,
    this.disableListener = false,
    this.onFirstFetchCatch,
    this.fsListen,
    this.withoutNewItemsToList = false,
    this.presortOnItemsAdded = false,
    this.isManualFetch = false,
    this.disableConcurrentFetch = false,
    this.whenRefresh,
  })  : _type = FBTypes.cloudFirestore,
        assert(forEachSnap != null),
        this.dbQuery = null,
        this.forEachJson = null,
        this.dbReference = null,
        this.onNextQuery = null,
        this.dbListen = null;

  /// List view for Firebase DB
  FBListViewLogic.realtimeDatabase({
    required this.forEachJson,
    this.dbQuery,
    this.dbReference,
    this.orderBy,
    this.onFetchCatch,
    this.fetchDelay = 0,
    this.refresher,
    this.onFirstFetchStatus,
    this.limitBy = 30,
    this.onNextQuery,
    this.disableListener = false,
    this.onFirstFetchCatch,
    this.dbListen,
    this.withoutNewItemsToList = false,
    this.presortOnItemsAdded = false,
    this.isManualFetch = false,
    this.disableConcurrentFetch = false,
    this.whenRefresh,
  })  : assert(!(dbQuery == null && dbReference == null)),
        assert(forEachJson != null),
        _type = FBTypes.realtimeDatabase,
        this.fsQuery = null,
        this.forEachSnap = null,
        this.fsListen = null,
        this.numberOfFirstFetch = 1;

  /* -------------------------------- Lifecycle ------------------------------- */

  @override
  void initState() {
    super.initState();
    this.init(orderBy: orderBy, presortOnItemsAdded: presortOnItemsAdded);
    _refreshController = RefreshController();

    _status(false).then((_) {
      _pagingController.addPageRequestListener((pageKey) {
        if (_isFirstFetchCompleted) _fetchPage();
      });

      if (!this.isManualFetch) initFetch();
    }).catchError((err) {
      if (onFirstFetchCatch != null) onFirstFetchCatch!(err);
    });

    /// Fetch initialization if user is using infinite scroll pagination.
  }

  /// Used when [isManualFetch] is true.
  /// This will fetch the first data
  /// when called.
  Future<void> initFetch() async {
    /// Set status as loading.
    refresh(ViewState.asLoading);

    await Future.microtask(() async {
      try {
        await Future.delayed(Duration(milliseconds: fetchDelay));

        if (_type == FBTypes.cloudFirestore) {
          try {
            await this.onRefresh();
            await _status(true);
            if (!this.disableListener) _cloudFirestoreListen();
          } catch (err) {
            if (this.onFirstFetchCatch != null) await onFirstFetchCatch!(err);
          }
        } else if (_type == FBTypes.realtimeDatabase) {
          try {
            await this.onRefresh();
            await _status(true);
            if (!this.disableListener) _realtimeDatabaseListen();
          } catch (err) {
            if (this.onFirstFetchCatch != null) await onFirstFetchCatch!(err);
          }
        }
      } catch (err) {
        refresh(ViewState.asError);
        await onFetchCatch!(err);
      }
    });

    /// Callback refresher
    if (refresher != null) refresher!(this.onRefresh);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _cloudFirestoreSubscription?.cancel();
    _realtimeDatabaseSubscriptionOnAdded?.cancel();
    _realtimeDatabaseSubscriptionOnChanged?.cancel();
    _refreshController?.dispose();
    super.dispose();
  }

  /* -------------------------------------------------------------------------- */
  /*                              Private variable                              */
  /* -------------------------------------------------------------------------- */

  /// Paging controller for the list pagination alternative.
  /// This if user wants to use the infinite scroll pagination
  /// package.
  PagingController<int, T> get pagingController => _pagingController;
  final PagingController<int, T> _pagingController =
      PagingController(firstPageKey: 0);

  /// The refresh controller for smart refresher.
  RefreshController? get refreshController => _refreshController;
  RefreshController? _refreshController;

  /// Determine if the first fetch complete.
  bool _isFirstFetchCompleted = false;
  Future<void> _status(bool val) async {
    _isFirstFetchCompleted = val;
    if (this.onFirstFetchStatus != null) await this.onFirstFetchStatus!(val);
  }

  /// Keep track of snaps and subs
  _fs.DocumentSnapshot? _lastSnap;
  StreamSubscription? _cloudFirestoreSubscription;
  StreamSubscription? _realtimeDatabaseSubscriptionOnAdded;
  StreamSubscription? _realtimeDatabaseSubscriptionOnChanged;

  /* -------------------------------------------------------------------------- */
  /*                                  Functions                                 */
  /* -------------------------------------------------------------------------- */

  ///The default limit value.
  static const REMOVE_LIMIT_MESSAGE = 'REMOVE LIMIT ON FIRESTORE QUERY!';

  @override
  void addItems(List<T?> data) {
    super.addItems(data);
    _pagingController.itemList = this.items;
    _pagingController.appendPage([], this.items.length);
  }

  @override
  void replaceItems(List<T?> data) {
    super.replaceItems(data);
    _pagingController.itemList = this.items;
    _pagingController.appendPage([], this.items.length);
  }

  /// Fetch page for the infinite page scroll
  /// pagination library.
  Future<void> _fetchPage() async {
    try {
      final isLastPage = this.items.length == 0;
      if (isLastPage && !_isFirstFetchCompleted) {
        await this.onRefresh();
      } else {
        await this.onLoading();
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  /// On First time load.
  Future<void> onRefresh() async {
    refresh(ViewState.asLoading);

    if (whenRefresh != null) await whenRefresh!(_isFirstFetchCompleted);

    if (_type == FBTypes.cloudFirestore)
      this.replaceItems(await _firestoreFetch());
    else if (_type == FBTypes.realtimeDatabase)
      this.replaceItems(await _realtimeDatabaseFetch());

    refresh(ViewState.asComplete);
  }

  /// Load next pagination.
  /// This is usually assigned on the
  /// SmartRefresher onLoading.
  Future<void> onLoading() async {
    if (_type == FBTypes.cloudFirestore) {
      this.addItems(await _firestoreFetch(isNext: true));
    } else if (_type == FBTypes.realtimeDatabase) {
      this.addItems(await _realtimeDatabaseFetch(isNext: true));
    }
    refresh(ViewState.asComplete);
  }

  /// Add Firebase Database Real-time items.
  Future<void> addFirebaseItems(_db.Event event) async {
    this.addItems([
      await forEachJson!(event.snapshot.key,
          Map<String, dynamic>.from(event.snapshot.value ?? {})),
    ]);
  }

  Future<void> _updateRealtimeData(event) async {
    try {
      if (!this.withoutNewItemsToList) await this.addFirebaseItems(event);

      if (this.dbListen != null) await this.dbListen!(this, event);
    } catch (err) {
      _printErr(err, isItem: true);
    }
    refresh(ViewState.asComplete);
  }

  Future<void> _realtimeDatabaseListen() async {
    _realtimeDatabaseSubscriptionOnAdded =
        (dbReference?.limitToLast(1) ?? dbQuery)
            ?.onChildAdded
            .listen((event) async {
      if (super.isDisposed) return;
      await _updateRealtimeData(event);
    });

    _realtimeDatabaseSubscriptionOnChanged =
        (dbReference?.limitToLast(1) ?? dbQuery)
            ?.onChildChanged
            .listen((event) async {
      if (super.isDisposed) return;
      await _updateRealtimeData(event);
    });
  }

  _fs.Query? _firestoreQuery() {
    _fs.Query? query;
    try {
      if (this._isFirstFetchCompleted)
        query = fsQuery!.limit(this.limitBy);
      else
        query = fsQuery!.limit(this.numberOfFirstFetch);
    } catch (err) {
      _printErr(REMOVE_LIMIT_MESSAGE + ' -> $err');
      query = fsQuery;
    }
    return query;
  }

  /// Add new Firestore items to the logic list.
  Future<void> addFirestoreItems(_fs.QuerySnapshot data) async {
    if (!this.disableConcurrentFetch) {
      this.addItems(List<T?>.from(
          await Future.wait<T?>(data.docChanges.map((docChange) async {
            try {
              return await forEachSnap!(docChange.doc);
            } catch (err) {
              _printErr(err, isItem: true);
              return null;
            }
          })),
          growable: true));
    } else {
      final newItems = <T?>[];
      for (final docChange in data.docChanges) {
        try {
          final item = await forEachSnap!(docChange.doc);
          if (item != null) newItems.add(item);
        } catch (err) {
          _printErr(err, isItem: true);
        }
      }
      this.addItems(newItems);
    }
  }

  Future<void> _cloudFirestoreListen() async {
    _cloudFirestoreSubscription =
        _firestoreQuery()?.snapshots().listen((data) async {
      try {
        if (super.isDisposed) return;
        if (!this.withoutNewItemsToList) await this.addFirestoreItems(data);
        if (this.fsListen != null) await this.fsListen!(this, data);
        await _status(true);
        refresh(ViewState.asComplete);
      } catch (err) {
        _printErr(err, isItem: false);
      }
    });
  }

  Future<List<T?>> _realtimeDatabaseFetch({bool isNext = false}) async {
    List<T?> data = [];

    try {
      var query =
          dbQuery ?? dbReference!.orderByKey().limitToLast(this.limitBy);
      if (isNext)
        query = this.onNextQuery != null
            ? this.onNextQuery!(query, getItems<T>())
            : query.endAt(getItems<T>().last!.id);
      var snap = await query.once();
      var jsonObj = Map<String, dynamic>.from(snap.value ?? {});

      if (!this.disableConcurrentFetch) {
        data = await Future.wait<T?>(jsonObj.entries.toList().map((each) async {
          try {
            return await forEachJson!(
                each.key, Map<String, dynamic>.from(each.value ?? {}));
          } catch (err) {
            _printErr(err, isItem: true);
            return null;
          }
        }));
      } else {
        for (final each in jsonObj.entries.toList()) {
          try {
            final item = await forEachJson!(
                each.key, Map<String, dynamic>.from(each.value ?? {}));
            if (item != null) data.add(item);
          } catch (err) {
            _printErr(err, isItem: true);
          }
        }
      }
    } catch (err) {
      if (onFetchCatch != null) await onFetchCatch!(err);
      _printErr(err);
    }

    if (isNext)
      _refreshController?.loadComplete();
    else
      _refreshController?.refreshCompleted();
    return data;
  }

  Future<List<T?>> _firestoreFetch({bool isNext = false}) async {
    List<T?> data = [];
    _fs.Query? query = _firestoreQuery();

    try {
      if (isNext && _lastSnap != null)
        query = query!.startAfterDocument(_lastSnap!);
      var doc = await query!.get();
      _lastSnap = doc.docs.last;
      data = await Future.wait<T?>(doc.docs.map((snap) async {
        try {
          return await forEachSnap!(snap);
        } catch (err) {
          _printErr(err, isItem: true);
          return null;
        }
      }));
    } catch (err) {
      if (onFetchCatch != null) await onFetchCatch!(err);
      _printErr(err);
    }

    if (isNext)
      _refreshController?.loadComplete();
    else
      _refreshController?.refreshCompleted();
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
