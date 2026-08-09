import Foundation
import CoreBluetooth

/// Quản lý kết nối BLE tới ESP32 HUD + auto-reconnect khi mất tín hiệu
class BLEManager: NSObject {
    static let serviceUUID = CBUUID(string: "DD3F0AD1-6239-4E1F-81F1-91F6C9F01D86")
    static let writeUUID = CBUUID(string: "DD3F0AD3-6239-4E1F-81F1-91F6C9F01D86")

    var onStatusChange: ((String) -> Void)?
    var onConnectedChange: ((Bool) -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var reconnectTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    /// Gửi JSON tới HUD
    func send(json: [String: Any]) {
        guard let ch = writeCharacteristic,
              let data = try? JSONSerialization.data(withJSONObject: json),
              let peripheral = peripheral else { return }
        peripheral.writeValue(data, for: ch, type: .withResponse)
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScan()
        } else {
            onStatusChange?("Bluetooth đang tắt")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? ""
        if name.contains("ESP32_Sygic_HUD") || name.contains("CatDrive") {
            self.peripheral = peripheral
            central.stopScan()
            central.connect(peripheral, options: nil)
            onStatusChange?("Đang kết nối \(name)...")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([BLEManager.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        onConnectedChange?(false)
        onStatusChange?("Mất kết nối — đang thử lại...")
        // Auto-reconnect (phản hồi "hay mất tín hiệu" của V5)
        writeCharacteristic = nil
        startScan()
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == BLEManager.serviceUUID }) else {
            onStatusChange?("Không thấy service HUD")
            return
        }
        peripheral.discoverCharacteristics([BLEManager.writeUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        writeCharacteristic = service.characteristics?.first(where: { $0.uuid == BLEManager.writeUUID })
        if writeCharacteristic != nil {
            onConnectedChange?(true)
            onStatusChange?("Đã kết nối HUD ✓")
        } else {
            onStatusChange?("Không thấy chữ WRITE")
        }
    }
}
