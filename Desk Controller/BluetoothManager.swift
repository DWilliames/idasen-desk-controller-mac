//
//  BluetoothManager.swift
//  Desk Controller
//
//  Created by David Williames on 11/1/21.
//

import Foundation
@preconcurrency import CoreBluetooth

@MainActor
class BluetoothManager: NSObject {

    var stopOnFirstConnection = true

    // Singleton for managing it all
    static let shared = BluetoothManager()

    var centralManager: CBCentralManager?

    var onCentralManagerStateChange: (CBCentralManager?) -> Void = { _ in }

    var onConnectedPeripheralChange: (CBPeripheral?) -> Void = { _ in  }
    private var connectPeripheralRSSI: NSNumber?

    /// The peripheral we are attempting to connect to (set in didDiscover)
    private var pendingPeripheral: CBPeripheral?

    /// The peripheral that is fully connected (set in didConnect, cleared in didDisconnect)
    private(set) var connectedPeripheral: CBPeripheral?

    override init() {
        super.init()
        startScanning()
    }

    func startScanning() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    func reconnect() {
        // Try connected peripheral first, then pending
        let peripheral = connectedPeripheral ?? pendingPeripheral
        guard let peripheral, peripheral.state == .disconnected else {
            return
        }
        centralManager?.connect(peripheral, options: nil)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            centralManager = central
            onCentralManagerStateChange(central)

            print("[BluetoothManager] state -> \(central.state.rawValue) (poweredOn=\(central.state == .poweredOn))")

            guard central.state == .poweredOn else {
                return
            }

            if let peripheral = connectedPeripheral ?? pendingPeripheral, peripheral.state == .disconnected {
                print("[BluetoothManager] reconnecting known peripheral \(peripheral.identifier)")
                central.connect(peripheral, options: nil)
                return
            }

            // Adopt any peripheral macOS already has connected on the IDÅSEN
            // service — these will NOT show up via scanForPeripherals because
            // they don't advertise while held by another connection.
            let alreadyConnected = central.retrieveConnectedPeripherals(
                withServices: [DeskPeripheral.deskControlServiceUUID]
            )
            if let desk = alreadyConnected.first {
                print("[BluetoothManager] adopting already-connected peripheral \(desk.identifier) name=\(desk.name ?? "—")")
                pendingPeripheral = desk
                central.connect(desk, options: nil)
                return
            }

            print("[BluetoothManager] no already-connected desk, starting advertising scan")
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Extract Sendable primitives BEFORE crossing into the MainActor closure —
        // `advertisementData` is `[String: Any]` and can't be sent across isolations.
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let rssi = RSSI.intValue

        MainActor.assumeIsolated {
            let cachedName = peripheral.name
            // Match the desk's advertised name. Case-insensitive, and inspects
            // `CBAdvertisementDataLocalNameKey` too so a desk that hasn't been
            // paired before (and therefore has no `peripheral.name` yet) still
            // matches on the first scan.
            let looksLikeDesk = (cachedName?.lowercased().contains("desk") ?? false)
                || (localName?.lowercased().contains("desk") ?? false)

            guard pendingPeripheral != peripheral && connectedPeripheral != peripheral else {
                return
            }
            guard looksLikeDesk else { return }

            let isClosestMatchingPeripheral = (connectPeripheralRSSI != nil && rssi < connectPeripheralRSSI!.intValue)

            if pendingPeripheral == nil || isClosestMatchingPeripheral {
                central.connect(peripheral, options: nil)
                connectPeripheralRSSI = RSSI
                pendingPeripheral = peripheral
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            guard peripheral == pendingPeripheral else {
                return
            }

            if stopOnFirstConnection {
                central.stopScan()
            }

            // Promote pending → connected
            connectedPeripheral = peripheral
            pendingPeripheral = nil
            onConnectedPeripheralChange(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            if peripheral == connectedPeripheral {
                connectedPeripheral = nil
            }
            if peripheral == pendingPeripheral {
                pendingPeripheral = nil
            }
            connectPeripheralRSSI = nil

            onConnectedPeripheralChange(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            if peripheral == pendingPeripheral {
                pendingPeripheral = nil
            }
            connectPeripheralRSSI = nil

            onConnectedPeripheralChange(nil)
        }
    }

}
