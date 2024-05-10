import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/web.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/Material.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(MainScreen());
}

// ignore: must_be_immutable
class MainScreen extends StatelessWidget {
  MainScreen({super.key});

  // service.checkPendingTX(id: '');

  final ZainCashService client = ZainCashService(
    isProduction: false,
  );
  int amount = 250;
  int days = 0;
  int plan = 0;
  int points = 0;
  Map<String, dynamic> orderID = {};

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              orderID = await client.createTransaction(amount, '$days Days');
              Logger().f("orderID$orderID");
              // Get.to(() => ZaincashHTTP(
              //       orderID: orderID,
              //       amount: amount,
              //       days: days,
              //       points: points,
              //       plan: plan,
              //     ));
            },
            child: const Text("press here ffk"),
          ),
        ),
      ),
    );
  }
}

class ZainCashService {
  String merchantID = '5ffacf6612b5777c6d44266f';
  String secret =
      '\$2y\$10\$hBbAZo2GfSSvyqAyV2SaqOfYewgYpfR1O19gIh4SqyGWdmySZYPuS';
  String msisdn = '9647835077893';

  bool isProduction = false;

  Map<String, String> initUrl = {
    'url': 'test.zaincash.iq',
    'route': 'transaction/init'
  };
  String requestUrl = 'https://test.zaincash.iq/transaction/pay?id=';

  ZainCashService({required this.isProduction}) {
    if (isProduction) {
      initUrl['url'] = 'api.zaincash.iq';
      requestUrl = 'https://api.zaincash.iq/transaction/pay?id=';
    }
  }

  Dio _dio() {
    final dio = Dio(BaseOptions(
      headers: {
        'Content-Type': 'application/json',
        "Access-Control-Allow-Origin": "*",
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Redirect request through a proxy
        options.path = 'http://your-proxy-server.com/${options.path}';
        return handler.next(options);
      },
    ));

    return dio;
  }

  Future<dynamic> checkTransaction(String token) async {
    try {
      JWT res = JWT.verify(token, SecretKey(secret));
      return res.payload;
    } on JWTExpiredException {
      Get.snackbar('Error ', 'Token has expired');
    } on JWTException catch (e) {
      Get.snackbar('Error in JWT', 'Error decoding token: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> createTransaction(
    int amount,
    String type,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expirationTime = now + (60 * 60 * 40); // 60 hours from now
    final orderId = const Uuid().v4();
    final data = JWT({
      'msisdn': msisdn,
      'amount': amount,
      'serviceType': type,
      'orderId': orderId,
      'redirectUrl': 'https://com.oriomonitor',
      'iat': now,
      'exp': expirationTime,
    });

    try {
      final token = data.sign(SecretKey(secret));
      final postData = {'token': token, 'merchantId': merchantID, 'lang': 'ar'};
      // Make HTTP Request to Zaincash API
      // var url = Uri.https(initUrl['url']!, initUrl['route']!);
      Logger().d("postData$postData");
      var url = 'https://${initUrl['url']}/${initUrl['route']}';
      var response = await _dio().post(url, data: jsonEncode(postData));

      // var response =
      //     await http.post(url, body: json.encode(postData), headers: header);
      Logger().f("response $response");
      // print('Response status: ${response.body}');
      final results = response.data;

      // final results = json.decode(response.body);
      // print('Response body: ${results['id']}');
      return results;
    } on JWTException catch (ex) {
      return {'Error': ex.message.toString()};
    } catch (e) {
      Logger().f("e $e");
      return {'Error': e.toString()};
    }
  }

  Future<dynamic> checkPendingTX({required id}) async {
    final data = JWT({
      'id': id,
      'msisdn': msisdn,
      'iat': DateTime.now().millisecondsSinceEpoch,
      'exp': DateTime.now().millisecondsSinceEpoch + 60 * 60 * 4,
    });

    final newToken = data.sign(SecretKey(secret));
    final dataToPost = {
      'token': newToken,
      'merchantId': merchantID,
    };
    final Map<String, String> header = {'Content-Type': 'application/json'};

    // Make HTTP Request to Zaincash API
    var url = Uri.https(initUrl['url']!, 'transaction/get');
    var response =
        await http.post(url, body: json.encode(dataToPost), headers: header);

    dynamic results = json.decode(response.body);
    return results;
  }
}

class ZaincashHTTP extends StatefulWidget {
  final Map<String, dynamic> orderID;
  final int amount, days, points, plan;

  const ZaincashHTTP({
    required this.orderID,
    required this.amount,
    required this.days,
    required this.points,
    required this.plan,
    super.key,
  });

  @override
  State<ZaincashHTTP> createState() => ZaincashHTTPState();
}

class ZaincashHTTPState extends State<ZaincashHTTP> {
  late InAppWebViewController webView;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri.uri(Uri.parse(
              '${ZainCashService(isProduction: false).requestUrl}${widget.orderID['id']}')),
        ),
        onWebViewCreated: (controller) {
          webView = controller;
        },
        onProgressChanged: (controller, progress) {
          // Update loading bar or state.
        },
        onLoadStart: (controller, url) {},
        onLoadStop: (controller, url) async {
          if (url.toString().contains('token=')) {
            final uri = Uri.parse(url.toString());
            final token = uri.queryParameters['token'];
            if (token != null) {
              var payload = await ZainCashService(isProduction: true)
                  .checkTransaction(token);
              if (payload['status'] != null) {
                debugPrint('payment success');
                // Navigate away or update state
              } else {
                debugPrint('payment failed');
              }
            }
          }
        },
        onLoadError: (controller, url, code, message) {
          Get.snackbar('Error', 'Failed to load the page: $message');
        },
        onLoadHttpError: (controller, url, statusCode, description) {
          Get.snackbar('HTTP Error', 'HTTP error $statusCode: $description');
        },
      ),
    );
  }
}

/*
class ZaincashHTTP extends StatefulWidget {
  final Map<String, dynamic> orderID;
  final int amount, days, points, plan;

  const ZaincashHTTP(
      {required this.orderID,
      required this.amount,
      required this.days,
      required this.points,
      required this.plan,
      super.key});

  @override
  State<ZaincashHTTP> createState() => ZaincashHTTPState();
}

class ZaincashHTTPState extends State<ZaincashHTTP> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: WebViewWidget(
          layoutDirection: TextDirection.ltr,
          controller: WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            // ..setBackgroundColor(Color.fromARGB(226, 6, 5, 23))
            ..setNavigationDelegate(
              NavigationDelegate(
                onProgress: (int progress) {
                  // Update loading bar.
                },
                onPageStarted: (String url) {},
                onPageFinished: (String url) {},
                onWebResourceError: (WebResourceError error) {
                  final snackBar = SnackBar(
                    content: Text(error.description),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
                onNavigationRequest: (NavigationRequest request) async {
                  if (request.url.contains('token=')) {
                    final uri = Uri.parse(request.url);
                    final token = uri.queryParameters['token'];
                    if (token != null) {
                      var payload = await ZainCashService(isProduction: true)
                          .checkTransaction(token);
                      if (payload['status'] != null) {
                        debugPrint('payment success');
                        //   Get.offAll(() => PaymentCheck(
                        //         id: payload['id'],
                        //         days: widget.days,
                        //         points: widget.points,
                        //         plan: widget.plan,
                        //       ));
                        // } else {
                        // failed payment
                        debugPrint('payment failed');
                      }
                    }
                    return NavigationDecision.prevent;
                  }
                  return NavigationDecision.navigate;
                },
              ),
            )
            ..loadRequest(Uri.parse(
                '${ZainCashService(isProduction: true).requestUrl}${widget.orderID['id']}'))),
    );
  }
}
*/

class PaymentCheck extends StatefulWidget {
  final String id;
  final int days, points, plan;

  const PaymentCheck(
      {super.key,
      required this.id,
      required this.days,
      required this.points,
      required this.plan});

  @override
  State<PaymentCheck> createState() => _PaymentCheckState();
}

class _PaymentCheckState extends State<PaymentCheck> {
  @override
  void initState() {
    super.initState();
  }

  void _navigateToHomePage(BuildContext context) {
    Get.snackbar('thankyou'.tr, 'bought-subs'.tr);
    Get.offAll(() => MainScreen());
  }

  Future<Map<String, int>> saveData() async {
    return {"5": 5};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future:
            ZainCashService(isProduction: true).checkPendingTX(id: widget.id),
        builder: (ctx, snapshot) {
          if (snapshot.hasData &&
              snapshot.data['status'] == 'completed' &&
              snapshot.data['operationId'] != null &&
              snapshot.data['operationDate'] != null) {
            // First Add the transaction to cloud
            return FutureBuilder(
                // future: FireStore().addUserPayment(
                //   snapshot.data,
                //   widget.days,
                //   widget.points,
                //   widget.plan,
                // ),
                future: saveData(),
                builder: (ctx, snapshot) {
                  // ignore: unrelated_type_equality_checks
                  if (snapshot.hasData && snapshot.data != false) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _navigateToHomePage(context);
                    });

                    // Show dialog or overlay here
                    return const SizedBox.shrink();
                  } else {
                    return Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 10),
                            Text('payment-confirming'.tr),
                            Text('afew-left'.tr),
                          ],
                        ),
                      ),
                    );
                  }
                });
          } else if (snapshot.hasData && snapshot.data['err'] != null) {
            return Scaffold(
              body: Center(child: Text('payment-error'.tr)),
            );
          } else if (snapshot.hasData && snapshot.data['status'] == 'failed') {
            return Scaffold(
              body: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/imgs/error.png',
                        // Replace with the path to your desired image
                        width: 200,
                        height: 200,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'payment-not-completed'.tr,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'check-balance'.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Get.offAll(() => const AuthScreen());
                        },
                        child: Text('return'.tr),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else if (!snapshot.hasData) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text('payment-confirming'.tr),
                    Text('weak-connection'.tr),
                  ],
                ),
              ),
            );
          } else {
            return Scaffold(
              body: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/imgs/error.png',
                        // Replace with the path to your desired image
                        width: 200,
                        height: 200,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'payment-not-completed'.tr,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'payment-canceled'.tr,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          // Get.offAll(() => const AuthScreen());
                        },
                        child: Text('return'.tr),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
