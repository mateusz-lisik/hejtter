import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:hejtter/posts_response.dart';
import 'package:hejtter/post_card.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class PostsTabView extends StatefulWidget {
  const PostsTabView({
    super.key,
    this.communityName,
  });

  final String? communityName;

  @override
  State<PostsTabView> createState() => _PostsTabViewState();
}

class _PostsTabViewState extends State<PostsTabView> {
  final client = http.Client();
  static const _pageSize = 5;

  final List<String> items = [
    '6h',
    '12h',
    '24h',
    'tydzień',
    'od początku',
  ];
  String _postsPeriod = '6h';

  final PagingController<int, PostItem> _hotPagingController =
      PagingController(firstPageKey: 1);
  final PagingController<int, PostItem> _topPagingController =
      PagingController(firstPageKey: 1);
  final PagingController<int, PostItem> _newPagingController =
      PagingController(firstPageKey: 1);

  Future<List<PostItem>?> _getHotPosts(int pageKey, int pageSize) async {
    var queryParameters = {
      'limit': '$pageSize',
      'page': '$pageKey',
      'orderBy': 'p.hot',
    };

    queryParameters = _addCommunityFilter(queryParameters);

    var response = await client.get(
      Uri.https('api.hejto.pl', '/posts', queryParameters),
    );

    return postFromJson(response.body).embedded?.items;
  }

  Future<List<PostItem>?> _getTopPosts(int pageKey, int pageSize) async {
    var queryParameters = {
      'limit': '$pageSize',
      'page': '$pageKey',
      'orderBy': 'numLikes',
    };

    queryParameters = _addCommunityFilter(queryParameters);

    switch (_postsPeriod) {
      case '6h':
        queryParameters.addEntries(<String, String>{
          'period': '6h',
        }.entries);
        break;
      case '12h':
        queryParameters.addEntries(<String, String>{
          'period': '12h',
        }.entries);
        break;
      case '24h':
        queryParameters.addEntries(<String, String>{
          'period': '24h',
        }.entries);
        break;
      case 'tydzień':
        queryParameters.addEntries(<String, String>{
          'period': 'week',
        }.entries);
        break;
      default:
        break;
    }

    var response = await client.get(
      Uri.https('api.hejto.pl', '/posts', queryParameters),
    );

    return postFromJson(response.body).embedded?.items;
  }

  Future<List<PostItem>?> _getNewPosts(int pageKey, int pageSize) async {
    var queryParameters = {
      'limit': '$pageSize',
      'page': '$pageKey',
      'orderBy': 'p.createdAt',
    };

    queryParameters = _addCommunityFilter(queryParameters);

    var response = await client.get(
      Uri.https('api.hejto.pl', '/posts', queryParameters),
    );

    return postFromJson(response.body).embedded?.items;
  }

  Map<String, String> _addCommunityFilter(Map<String, String> queryParameters) {
    if (widget.communityName != null) {
      queryParameters.addEntries(<String, String>{
        'community': widget.communityName!,
      }.entries);
    }

    return queryParameters;
  }

  Future<void> _fetchHotPage(int pageKey) async {
    try {
      final newItems = await _getHotPosts(pageKey, _pageSize);
      final isLastPage = newItems!.length < _pageSize;
      if (isLastPage) {
        _hotPagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _hotPagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _hotPagingController.error = error;
    }
  }

  Future<void> _fetchTopPage(int pageKey) async {
    try {
      final newItems = await _getTopPosts(pageKey, _pageSize);
      final isLastPage = newItems!.length < _pageSize;
      if (isLastPage) {
        _topPagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _topPagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _topPagingController.error = error;
    }
  }

  Future<void> _fetchNewPage(int pageKey) async {
    try {
      final newItems = await _getNewPosts(pageKey, _pageSize);
      final isLastPage = newItems!.length < _pageSize;
      if (isLastPage) {
        _newPagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _newPagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _newPagingController.error = error;
    }
  }

  @override
  void initState() {
    _hotPagingController.addPageRequestListener((pageKey) {
      _fetchHotPage(pageKey);
    });

    _topPagingController.addPageRequestListener((pageKey) {
      _fetchTopPage(pageKey);
    });

    _newPagingController.addPageRequestListener((pageKey) {
      _fetchNewPage(pageKey);
    });

    super.initState();
  }

  @override
  void dispose() {
    _hotPagingController.dispose();
    _topPagingController.dispose();
    _newPagingController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              children: [
                _buildHotTabBarView(),
                _buildTopTabBarView(),
                _buildNewTabBarView()
              ],
            ),
          ),
        ],
      ),
    );
  }

  RefreshIndicator _buildNewTabBarView() {
    return RefreshIndicator(
      onRefresh: () => Future.sync(
        () => _newPagingController.refresh(),
      ),
      child: PagedListView<int, PostItem>(
        pagingController: _newPagingController,
        padding: const EdgeInsets.all(10),
        builderDelegate: PagedChildBuilderDelegate<PostItem>(
          itemBuilder: (context, item, index) => PostCard(item: item),
        ),
      ),
    );
  }

  RefreshIndicator _buildTopTabBarView() {
    return RefreshIndicator(
      onRefresh: () => Future.sync(
        () => _topPagingController.refresh(),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildTopDropdown(),
          const SizedBox(height: 5),
          Expanded(
            child: PagedListView<int, PostItem>(
              pagingController: _topPagingController,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              builderDelegate: PagedChildBuilderDelegate<PostItem>(
                itemBuilder: (context, item, index) => PostCard(item: item),
              ),
            ),
          ),
        ],
      ),
    );
  }

  RefreshIndicator _buildHotTabBarView() {
    return RefreshIndicator(
      onRefresh: () => Future.sync(
        () => _hotPagingController.refresh(),
      ),
      child: PagedListView<int, PostItem>(
        pagingController: _hotPagingController,
        padding: const EdgeInsets.all(10),
        builderDelegate: PagedChildBuilderDelegate<PostItem>(
          itemBuilder: (context, item, index) => PostCard(item: item),
        ),
      ),
    );
  }

  TabBar _buildTabBar() {
    return const TabBar(
      indicatorColor: Color(0xff2295F3),
      indicatorPadding: EdgeInsets.symmetric(horizontal: 12),
      tabs: [
        Tab(child: Text('Gorące')),
        Tab(child: Text('Top')),
        Tab(child: Text('Nowe')),
      ],
    );
  }

  Widget _buildTopDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(50),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton2(
            buttonWidth: MediaQuery.of(context).size.width,
            hint: Text(
              'Select Item',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).hintColor,
              ),
            ),
            items: items
                .map((item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    ))
                .toList(),
            value: _postsPeriod,
            onChanged: (value) {
              setState(() {
                _postsPeriod = value as String;
              });

              Future.sync(
                () => _topPagingController.refresh(),
              );
            },
          ),
        ),
      ),
    );
  }
}
