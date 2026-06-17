/// 首页首屏加载占位视图（关注流与分区流共用）。
import 'package:flutter/material.dart';

/// 居中的"加载中..."占位组件。
class HomeLoadingIndicator extends StatelessWidget {
  const HomeLoadingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('加载中...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
