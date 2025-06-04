//
//  BluetoothManager.swift
//  Desk Controller
//
//  Created by David Williames on 11/1/21.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject {
    
    var stopOnFirstConnection = true
    
    // Singleton for managing it all
    static let shared = BluetoothManager()
    
    var centralManager: CBCentralManager?
    
    var onCentralManagerStateChange: (CBCentralManager?) -> Void = { _ in }
    
    var onConnectedPeripheralChange: (CBPeripheral?) -> Void = { _ in  }
    private var connectPeripheralRSSI: NSNumber?
    var connectedPeripheral: CBPeripheral? // Or is currently being connected to

    
    // Not currently used... just in case I want to handle multiple desks at once
    var onAvailablePeripheralsChange: ([CBPeripheral]) -> Void = { _ in }
    private var availablePeripherals = [CBPeripheral]() {
        didSet {
            onAvailablePeripheralsChange(availablePeripherals)
        }
    }
    
    
    // It will only match if the Name contains 'Desk' in it
    var matchCriteria: (CBPeripheral) -> Bool = { peripheral in
        guard let name = peripheral.name, name.contains("Desk") else {
            return false
        }
        return true
    }
    
    
    override init() {
        super.init()
        startScanning()
    }
    
    func startScanning() {
        if centralManager == nil {
            let queue = DispatchQueue(label: "BT_queue")
            centralManager = CBCentralManager(delegate: self, queue: queue)
        }
    }
    
    func reconnect() {
        guard let peripheral = connectedPeripheral,
              peripheral.state == .disconnected else {
                  return
        }
        
        centralManager?.connect(peripheral, options: nil)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        centralManager = central
        onCentralManagerStateChange(central)
        
        guard central.state == .poweredOn else {
            return
        }
        
        if let connectedPeripheral = connectedPeripheral, connectedPeripheral.state == .disconnected {
            // Reconnect to any previous desk
            central.connect(connectedPeripheral, options: nil)
            return
        }
        // Start scanning for all peripherals
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // print("Discovered peripheral: \(peripheral) • \(advertisementData) • \(RSSI)")
        
        // Make sure it's not already connected & meets our matching criteria
        guard connectedPeripheral != peripheral, matchCriteria(peripheral) else {
            return
        }
        
        // Add it to the available peripherals if it's not already there
        if !availablePeripherals.contains(peripheral) {
            availablePeripherals.append(peripheral)
        }
        
        let isClosestMatchingPeripheral = (connectPeripheralRSSI != nil && RSSI.intValue > connectPeripheralRSSI!.intValue)
        
        // If it's the first match or it's the closest one; update the connect peripheral
        if connectedPeripheral == nil || isClosestMatchingPeripheral {
            
            // Connect to the new one
            central.connect(peripheral, options: nil)
            
            connectPeripheralRSSI = RSSI
            connectedPeripheral = peripheral
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // print("Connected to peripheral: \(peripheral)")
        
        // Make sure it's the one we're connecting to
        guard peripheral == connectedPeripheral else {
            // print("Not the one we're tracking")
            return
        }
        
        if stopOnFirstConnection {
            central.stopScan()
        }
        
        onConnectedPeripheralChange(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // print("Disconnected to peripheral: \(peripheral)")
        
        // Make sure it's the one we're connecting to
        guard peripheral == connectedPeripheral else {
            // print("Not the one we're tracking")
            return
        }
        
        connectPeripheralRSSI = nil
        connectedPeripheral = nil
        
        onConnectedPeripheralChange(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Make sure it's the one we're connecting to
        guard peripheral == connectedPeripheral else {
            // print("Not the one we're tracking")
            return
        }
        
        connectPeripheralRSSI = nil
        connectedPeripheral = nil
        
        onConnectedPeripheralChange(nil)
    }
  
}
