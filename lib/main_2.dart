import 'dart:async';
import 'dart:ui' as ui;


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final TextEditingController urlText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    urlText.text = "https://i.imgur.com/3D4Dxu1.jpg";
    return MaterialApp(
        home: SafeArea(
          child: Scaffold(
            appBar: AppBar(title: const Text("Image Caching")),
            body: ListView(
              children: [
                TextField(
                    controller: urlText,
                    onSubmitted: (value) => setState(() {
                      urlText.text = value;
                    })),
                MyImage(customImageProvider: CustomNetworkImage(urlText.text)),
          ],
        ),
      ),
    ));
  }
}

class MyImage extends StatefulWidget {
  const MyImage({
    super.key,
    required this.customImageProvider,
  });

  final CustomNetworkImage customImageProvider;

  @override
  State<MyImage> createState() => _MyImageState();
}

class _MyImageState extends State<MyImage> {
  ImageStream? _imageStream;
  ImageInfo? _imageInfo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getImage();
  }

  @override
  void didUpdateWidget(MyImage oldWidget) {
    print("update");
    super.didUpdateWidget(oldWidget);
    if (widget.customImageProvider != oldWidget.customImageProvider) {
      _getImage();
    }
  }

  void _getImage() {
    final ImageStream? oldImageStream = _imageStream;
    _imageStream = widget.customImageProvider
        .resolve(createLocalImageConfiguration(context));
    if (_imageStream!.key != oldImageStream?.key) {
      print("------------");
      final ImageStreamListener listener = ImageStreamListener(_updateImage);
      oldImageStream?.removeListener(listener);
      _imageStream!.addListener(listener);
    }
  }

  void _updateImage(ImageInfo imageInfo, bool synchronousCall) {
    setState(() {
      // Trigger a build whenever the image changes.
      _imageInfo?.dispose();
      _imageInfo = imageInfo;
    });
  }

  @override
  void dispose() {
    _imageStream?.removeListener(ImageStreamListener(_updateImage));
    _imageInfo?.dispose();
    _imageInfo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawImage(
      image: _imageInfo?.image, // this is a dart:ui Image object
      scale: _imageInfo?.scale ?? 1.0,
    );
  }
}

@immutable
class CustomNetworkImage extends ImageProvider<http.Response> {
  const CustomNetworkImage(this.url);

  final String url;

  @override
  Future<http.Response> obtainKey(ImageConfiguration configuration) async {
    final Uri result = Uri.parse(url);
    final http.Response response = await http.get(result);
    print(response.headers);
    return SynchronousFuture<http.Response>(response);
  }

  @override
  ImageStreamCompleter loadImage(http.Response key, ImageDecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
    StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: getCodec(key),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      debugLabel: '"key"',
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<http.Response>('Response', key),
      ],
    );
  }

  Future<ui.Codec> getCodec(http.Response response) async{
    return await ui.instantiateImageCodec(response.bodyBytes);
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'CustomNetworkImage')}("$url")';
}