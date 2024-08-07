package com.example.coletor


import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.kontakt.sdk.android.ble.configuration.ScanMode
import com.kontakt.sdk.android.ble.device.BeaconRegion
import com.kontakt.sdk.android.ble.manager.ProximityManager
import com.kontakt.sdk.android.ble.manager.ProximityManagerFactory
import com.kontakt.sdk.android.ble.manager.listeners.IBeaconListener
import com.kontakt.sdk.android.common.KontaktSDK
import com.kontakt.sdk.android.common.profile.IBeaconDevice
import com.kontakt.sdk.android.common.profile.IBeaconRegion
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID


class MainActivity : FlutterActivity() {
    private var proximityManager: ProximityManager? = null
    private val CHANNEL = "samples.flutter.dev/beacons"
    val values = mutableListOf<MutableList<Int>>()
    var eventsSink: EventChannel.EventSink? = null

    override fun onStart() {
        super.onStart()
        checkPermissions()
        KontaktSDK.initialize("OJWPPKwLEuahTooyXDKxRkuiYMwQTbVZ")
        proximityManager = ProximityManagerFactory.create(this)
        proximityManager?.configuration()
            ?.deviceUpdateCallbackInterval(10)
            ?.scanMode(ScanMode.LOW_LATENCY)

        val beaconRegions: MutableCollection<IBeaconRegion> = ArrayList()

//        val region1: IBeaconRegion = BeaconRegion.Builder()
//            .identifier("Kontakt")
//            .proximity(UUID.fromString("f7826da6-4fa2-4e98-8024-bc5b71e0893e"))
//            .major(53462)
//            .minor(52894)
//            .build()
//
//        val region2: IBeaconRegion = BeaconRegion.Builder()
//            .identifier("Kontakt")
//            .proximity(UUID.fromString("f7826da6-4fa2-4e98-8024-bc5b71e0893e"))
//            .major(50411)
//            .minor(53503)
//            .build()
//
//        val region3: IBeaconRegion = BeaconRegion.Builder()
//            .identifier("Kontakt")
//            .proximity(UUID.fromString("f7826da6-4fa2-4e98-8024-bc5b71e0893e"))
//            .major(1888)
//            .minor(4774)
//            .build()
//
//        beaconRegions.add(region1)
//        beaconRegions.add(region2)
//        beaconRegions.add(region3)

        //proximityManager?.spaces()?.iBeaconRegions(beaconRegions)
        proximityManager?.setIBeaconListener(createIBeaconListener())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            if (call.method == "startListener") {
                values.clear()
                proximityManager!!.connect { proximityManager!!.startScanning() }
                result.success("start")
            } else if (call.method == "stopListener") {
                proximityManager!!.stopScanning()
                result.success(values)
            } else {
                result.notImplemented()
            }
        }
        //val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "timeHandlerEvent"); // timeHandlerEvent event name

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "bluetoothBleEvent")
                .setStreamHandler(
                    object : EventChannel.StreamHandler {
                        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                            eventsSink = events
                        }

                        override fun onCancel(arguments: Any?) {
                        }

                    }
                )
    }

    private fun createIBeaconListener(): IBeaconListener {
        return object : IBeaconListener {
            override fun onIBeaconDiscovered(iBeacon: IBeaconDevice, region: IBeaconRegion) {
                //Beacon discovered
            }
            val beaconAddresses = listOf("00:FA:B6:1D:DD:CF", "00:FA:B6:1D:DF:8E", "00:FA:B6:1D:DF:2E")

            override fun onIBeaconsUpdated(iBeacons: List<IBeaconDevice>, region: IBeaconRegion) {
                val rssiMap = iBeacons.associateBy({ it.address }, { it.rssi.toInt() })
                //println(rssiMap)

                val rssis = beaconAddresses.map { address -> rssiMap[address] ?: 0 }.toMutableList()

                if(eventsSink != null) {
                    println(rssis)
                    eventsSink!!.success(rssis)
                }
                values.add(rssis)

                //println("RSSI values: $rssis")
            }

            override fun onIBeaconLost(iBeacon: IBeaconDevice, region: IBeaconRegion) {
            }
        }
    }

    private fun checkPermissions() {
        val requiredPermissions = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION
        ) else arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.ACCESS_FINE_LOCATION
        )
        if (isAnyOfPermissionsNotGranted(requiredPermissions)) {
            ActivityCompat.requestPermissions(this, requiredPermissions, REQUEST_CODE_PERMISSIONS)
        }
    }

    private fun isAnyOfPermissionsNotGranted(requiredPermissions: Array<String>): Boolean {
        for (permission in requiredPermissions) {
            val checkSelfPermissionResult = ContextCompat.checkSelfPermission(this, permission)
            if (PackageManager.PERMISSION_GRANTED != checkSelfPermissionResult) {
                return true
            }
        }
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (grantResults.size > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            if (REQUEST_CODE_PERMISSIONS == requestCode) {
                Toast.makeText(this, "Permissions granted!", Toast.LENGTH_SHORT).show()
            }
        } else {
            //disableButtons();
            Toast.makeText(
                this,
                "Location permissions are mandatory to use BLE features on Android 6.0 or higher",
                Toast.LENGTH_LONG
            ).show()
        }
    }

    companion object {
        const val REQUEST_CODE_PERMISSIONS = 100
    }
}

