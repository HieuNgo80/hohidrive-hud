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
    private var isScanning = false

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn, !isScanning else { return }
        isScanning = true
        // Scan theo đúng service UUID của HUD — nhanh + không bắt nhầm thiết bị khác
        central.scanForPeripherals(withServices: [BLEManager.serviceUUID], options: nil)
    }

    private func stopScan() {
        if isScanning {
            central.stopScan()
            isScanning = false
        }
    }

    /// Gửi JSON tới HUD — dùng withoutResponse để không chờ ACK,
    /// tránh bị iOS timeout ngắt kết nối khi ESP đang bận vẽ OLED
    func send(json: [String: Any]) {
        guard let ch = writeCharacteristic,
              let data = try? JSONSerialization.data(withJSONObject: json),
              let peripheral = peripheral else { return }
        peripheral.writeValue(data, for: ch, type: .withoutResponse)
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
        stopScan()
        self.peripheral = peripheral
        central.connect(peripheral, options: nil)
        onStatusChange?("Đang kết nối HUD...")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([BLEManager.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onStatusChange?("Kết nối thất bại — thử lại...")
        // Thử lại sau 1 giây
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startScan()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        onConnectedChange?(false)
        onStatusChange?("Mất kết nối — đang thử lại...")
        writeCharacteristic = nil
        // Chờ 1 giây rồi quét lại cho ESP kịp quảng cáo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startScan()
        }
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
