//
//  DeskPeripheral.swift
//  Desk Controller
//
//  Created by David Williames on 10/1/21.
//

import Cocoa
@preconcurrency import CoreBluetooth

@MainActor
class DeskPeripheral: NSObject {

    public static let deskPositionServiceUUID = CBUUID.init(string: "99FA0020-338A-1024-8A49-009C0215F78A")
    public static let deskPositionCharacteristicUUID = CBUUID.init(string: "99FA0021-338A-1024-8A49-009C0215F78A")

    public static let deskControlServiceUUID = CBUUID.init(string: "99FA0001-338A-1024-8A49-009C0215F78A")
    public static let deskControlCharacteristicUUID = CBUUID.init(string: "99FA0002-338A-1024-8A49-009C0215F78A")

    static let heightPositionOffset: Float = 61.5 // min


    let peripheral: CBPeripheral

    var positionService: CBService?
    var positionCharacteristic: CBCharacteristic?

    var controlService: CBService?
    var controlCharacteristic: CBCharacteristic?


    var speed: Float = 0

    var hasLoadedPositionCharacteristicValues = false

    var onPositionChange: (Float) -> Void = { _ in }
    var position: Float? {
        didSet {
            if let position = position, hasLoadedPositionCharacteristicValues {
                onPositionChange(position)
            }
        }
    }

    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral

        super.init()

        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
}

extension DeskPeripheral: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            guard error == nil, peripheral == self.peripheral, let services = peripheral.services else {
                return
            }

            services.forEach { service in
                if service.uuid == DeskPeripheral.deskPositionServiceUUID {
                    positionService = service
                } else if service.uuid == DeskPeripheral.deskControlServiceUUID {
                    controlService = service
                } else {
                    return
                }

                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            guard error == nil, peripheral == self.peripheral, let characteristics = service.characteristics else {
                dbg("didDiscoverCharacteristics: error=\(String(describing: error)) same=\(peripheral == self.peripheral) count=\(service.characteristics?.count ?? -1)")
                return
            }

            characteristics.forEach { characteristic in
                if characteristic.uuid == DeskPeripheral.deskPositionCharacteristicUUID {
                    dbg("found positionCharacteristic, subscribing")
                    positionCharacteristic = characteristic
                    peripheral.readValue(for: characteristic)
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if characteristic.uuid == DeskPeripheral.deskControlCharacteristicUUID {
                    dbg("found controlCharacteristic")
                    controlCharacteristic = characteristic
                } else {
                    return
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            if let error {
                dbg("didWriteValueFor \(characteristic.uuid.uuidString) ERROR: \(error.localizedDescription)")
            } else {
                dbg("didWriteValueFor \(characteristic.uuid.uuidString) OK")
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            if characteristic == positionCharacteristic, let value = characteristic.value, error == nil {

                hasLoadedPositionCharacteristicValues = true

                // Position = 16 Little Endian – Unsigned
                // Speed = 16 Little Endian – Signed

                let positionValue = [value[0], value[1]].withUnsafeBytes {
                    $0.load(as: UInt16.self)
                }

                let speedValue = [value[2], value[3]].withUnsafeBytes {
                    $0.load(as: Int16.self)
                }

                speed = Float(speedValue)
                position = Float(positionValue) / 100 + DeskPeripheral.heightPositionOffset
                dbg("position notification: raw=\(positionValue) speed=\(speedValue) → \(String(format: "%.1f", position ?? -1)) cm")
            }
        }
    }

}
