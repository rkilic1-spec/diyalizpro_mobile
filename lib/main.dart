import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // OneSignal Tanımlaması (App ID buraya gelecek)
  // OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  // OneSignal.initialize("YOUR_ONESIGNAL_APP_ID");
  // OneSignal.Notifications.requestPermission(true);

  runApp(const MaterialApp(
    home: DiyalizProHome(),
    debugShowCheckedModeBanner: false,
  ));
}

class DiyalizProHome extends StatefulWidget {
  const DiyalizProHome({super.key});

  @override
  State<DiyalizProHome> createState() => _DiyalizProHomeState();
}

class _DiyalizProHomeState extends State<DiyalizProHome> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  
  // Ayarlar
  final String baseUrl = "https://www.diyalizpro.com";
  double progress = 0;
  bool isOffline = false;
  int _selectedIndex = 0;

  // Modern WebView Ayarları
  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllowFullscreen: true,
    useHybridComposition: true,
    allowsBackForwardNavigationGestures: true,
    cacheEnabled: true,
    javaScriptEnabled: true,
    domStorageEnabled: true,
  );

  late PullToRefreshController pullToRefreshController;

  @override
  void initState() {
    super.initState();
    
    // Çek-Yenile (Pull to Refresh)
    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: const Color(0xFF00D4FF)),
      onRefresh: () async {
        webViewController?.reload();
      },
    );

    // İnternet Kontrolü
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        isOffline = (result == ConnectivityResult.none);
      });
      if (!isOffline) webViewController?.reload();
    });
  }

  // Navigasyon İşlemi
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    String targetUrl = baseUrl;
    switch (index) {
      case 0: targetUrl = "$baseUrl/index.php"; break;
      case 1: targetUrl = "$baseUrl/modules/patients/index.php"; break;
      case 2: targetUrl = "$baseUrl/modules/leaves/reports.php"; break;
      case 3: targetUrl = "$baseUrl/update_config.php"; break;
    }
    
    webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(targetUrl))
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await webViewController?.canGoBack() ?? false) {
          webViewController?.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A2540),
        body: SafeArea(
          child: Stack(
            children: [
              // Ana WebView
              isOffline 
              ? _buildOfflineScreen()
              : InAppWebView(
                  key: webViewKey,
                  initialUrlRequest: URLRequest(url: WebUri(baseUrl)),
                  initialSettings: settings,
                  pullToRefreshController: pullToRefreshController,
                  onWebViewCreated: (controller) => webViewController = controller,
                  onLoadStart: (controller, url) {
                    setState(() { progress = 0; });
                  },
                  onLoadStop: (controller, url) async {
                    pullToRefreshController.endRefreshing();
                    setState(() { progress = 100; });
                  },
                  onProgressChanged: (controller, p) {
                    if (p == 100) pullToRefreshController.endRefreshing();
                    setState(() { progress = p / 100; });
                  },
                  onReceivedError: (controller, request, error) {
                    pullToRefreshController.endRefreshing();
                  },
                ),
              
              // Loading Indicator (Progress Bar)
              if (progress < 1.0)
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  color: const Color(0xFF00D4FF),
                  minHeight: 3,
                ),
            ],
          ),
        ),
        
        // Native Bottom Navigation Bar
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF0A2540),
          selectedItemColor: const Color(0xFF00D4FF),
          unselectedItemColor: Colors.white60,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Panel'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Hastalar'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Raporlar'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Ayarlar'),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 80, color: Colors.white30),
          const SizedBox(height: 20),
          const Text(
            "İnternet Bağlantısı Yok",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Lütfen bağlantınızı kontrol edin.",
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => webViewController?.reload(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF)),
            child: const Text("Tekrar Dene"),
          )
        ],
      ),
    );
  }
}
