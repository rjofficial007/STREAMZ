package com.example.streamz

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Network
import android.net.NetworkRequest
import android.os.Build
import android.net.LinkProperties
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "streamz/network_changes",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerNetworkCallback()
                emitNetworkChange(initial = true)
            }

            override fun onCancel(arguments: Any?) {
                unregisterNetworkCallback()
                eventSink = null
            }
        })
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "streamz/network_info",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getActiveNetworkInfo") {
                result.success(activeNetworkInfo())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun activeNetworkInfo(): Map<String, Any>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return null
        val network = manager.activeNetwork ?: return null
        val capabilities = manager.getNetworkCapabilities(network) ?: return null
        val isLocalTransport = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
        val properties = manager.getLinkProperties(network) ?: return null
        return mapOf(
            "isLocalTransport" to isLocalTransport,
            "interfaceName" to (properties.interfaceName ?: ""),
            "addresses" to properties.linkAddresses.map { it.address.hostAddress ?: "" },
        )
    }

    private fun registerNetworkCallback() {
        if (networkCallback != null) return
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return
        connectivityManager = manager
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = emitNetworkChange()
            override fun onLost(network: Network) = emitNetworkChange()
            override fun onLinkPropertiesChanged(
                network: Network,
                linkProperties: LinkProperties,
            ) = emitNetworkChange()
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                manager.registerDefaultNetworkCallback(callback)
            } else {
                manager.registerNetworkCallback(
                    NetworkRequest.Builder().build(),
                    callback,
                )
            }
            networkCallback = callback
        } catch (_: SecurityException) {
            networkCallback = null
        } catch (_: RuntimeException) {
            networkCallback = null
        }
    }

    private fun unregisterNetworkCallback() {
        val callback = networkCallback ?: return
        try {
            connectivityManager?.unregisterNetworkCallback(callback)
        } catch (_: RuntimeException) {
        }
        networkCallback = null
        connectivityManager = null
    }

    private fun emitNetworkChange(initial: Boolean = false) {
        mainHandler.post {
            eventSink?.success(
                if (initial) mapOf("initial" to true)
                else System.currentTimeMillis(),
            )
        }
    }

    override fun onDestroy() {
        eventSink = null
        unregisterNetworkCallback()
        super.onDestroy()
    }
}
