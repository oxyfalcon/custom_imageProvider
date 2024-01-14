import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

typedef ErrorListener = void Function(Object);

// ignore: must_be_immutable
class CustomNetworkImage extends CachedNetworkImageProvider {
  CustomNetworkImage(
    this.url, {
    this.maxHeight,
    this.maxWidth,
    this.scale = 1.0,
    this.errorListener,
    this.headers,
    required this.cacheManager,
    this.cacheKey,
    this.response,
  }) : super(url,
            maxHeight: maxHeight,
            cacheManager: cacheManager,
            scale: scale,
            errorListener: errorListener,
            headers: headers,
            cacheKey: cacheKey);

  http.Response? response;
  final CustomCache cacheManager;
  final String url;
  final String? cacheKey;
  final double scale;
  final ErrorListener? errorListener;
  final Map<String, String>? headers;
  final int? maxHeight;
  final int? maxWidth;
  bool isSameAsCache = true;
  String? cacheFilePath;

  @override
  Future<CachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) async {
    var value = await cacheManager.getSingleFile(url);
    response = await http.get(Uri.parse(url));
    print(value.existsSync());
    if (value.existsSync() && response!.bodyBytes != value.readAsBytesSync()) {
      print("I am here");
      isSameAsCache = false;
      cacheFilePath = value.path;
      File(value.path).deleteSync();
    } else {
      isSameAsCache = true;
    }
    return super.obtainKey(configuration);
  }

  @override
  ImageStreamCompleter loadImage(
      CachedNetworkImageProvider key, ImageDecoderCallback decode) {
    if (!isSameAsCache) {
      cacheManager.putFile(url, response!.bodyBytes,
          key: CustomCache.key);
    }
    return super.loadImage(key, decode);
  }
}

Stream<ui.Codec> _load(
  String url,
  String? cacheKey,
  StreamController<ImageChunkEvent> chunkEvents,
  Future<ui.Codec> Function(Uint8List) decode,
  BaseCacheManager cacheManager,
  int? maxHeight,
  int? maxWidth,
  Map<String, String>? headers,
  ErrorListener? errorListener,
  VoidCallback evictImage,
) async* {
  try {
    final stream = cacheManager is ImageCacheManager
        ? cacheManager.getImageFile(
            url,
            maxHeight: maxHeight,
            maxWidth: maxWidth,
            withProgress: true,
            headers: headers,
            key: cacheKey,
          )
        : cacheManager.getFileStream(
            url,
            withProgress: true,
            headers: headers,
            key: cacheKey,
          );

    await for (final result in stream) {
      if (result is FileInfo) {
        final file = result.file;
        final bytes = await file.readAsBytes();
        final decoded = await decode(bytes);
        yield decoded;
      }
    }
  } on Object catch (e) {
    scheduleMicrotask(() {
      evictImage();
    });

    errorListener?.call(e);
    rethrow;
  } finally {
    await chunkEvents.close();
  }
}

void main() async {
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  TextEditingController textEdit = TextEditingController();

  Future<http.Response> getResponse(String url) async =>
      await http.get(Uri.parse(url));

  @override
  Widget build(BuildContext context) {
    textEdit.text = "https://i.imgur.com/3D4Dxu1.jpg";
    return MaterialApp(
      home: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Image Caching"),
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  physics: const BouncingScrollPhysics(),
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad
                  },
                ),
                child: RefreshIndicator(
                  onRefresh: () {
                    Future<void> refresh() async {
                      http.Response response =
                          await http.get(Uri.parse(textEdit.text));
                      print(response.headers);
                      return;
                    }

                    return refresh.call();
                  },
                  child: ListView(
                    children: [
                      TextField(
                          controller: textEdit,
                          onSubmitted: (value) => textEdit.text = value),
                      Image(
                        image: CustomNetworkImage(
                          textEdit.text,
                          cacheManager: CustomCache._instance,
                        ),
                        width: constraints.hasBoundedWidth
                            ? constraints.maxWidth
                            : null,
                        height: constraints.hasBoundedHeight
                            ? constraints.maxHeight
                            : null,
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CustomCache extends CacheManager with ImageCacheManager {
  static const String key = "cache1";

  static final CustomCache _instance = CustomCache._();

  factory CustomCache() {
    return _instance;
  }

  CustomCache._() : super(Config(key));
}
