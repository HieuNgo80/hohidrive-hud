import Foundation
import CoreBluetooth

final class BLEManager: NSObject {
    static let serviceUUID = CBUUID(string: "4FAFC201-1FB5-459E-8FCC-C5C9C331914B")
    static let writeUUID   = CBUUID(string: "BEB5483E-36E1-4688-B7F5-EA07361B26A8")

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
        writeCharacteristic = nil
        peripheral = nil
        onConnectedChange?(false)
        onStatusChange?("Đang tìm HUD…")
        central.scanForPeripherals(withServices: [BLEManager.serviceUUID], options: nil)
    }

    private func stopScan() {
        if isScanning {
            central.stopScan()
            isScanning = false
        }
    }

    func send(json: [String: Any]) {
        guard let ch = writeCharacteristic,
              let data = try? JSONSerialization.data(withJSONObject: json),
              let peripheral = peripheral,
              peripheral.state == .connected else { return }
        peripheral.writeValue(data, for: ch, type: .withoutResponse)
    }

    func sendRaw(_ string: String) {
        guard let ch = writeCharacteristic,
              let data = string.data(using: .utf8),
              let peripheral = peripheral,
              peripheral.state == .connected else { return }
        peripheral.writeValue(data, for: ch, type: .withoutResponse)
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            onConnectedChange?(false)
            onStatusChange?("Đang tìm HUD…")
            startScan()
        case .poweredOff:
            stopScan()
            onConnectedChange?(false)
            onStatusChange?("Bluetooth đang tắt")
        default:
            stopScan()
            onConnectedChange?(false)
            onStatusChange?("Bluetooth chưa sẵn sàng")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        stopScan()
        self.peripheral = peripheral
        onConnectedChange?(false)
        onStatusChange?("Đang kết nối HUD…")
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        onConnectedChange?(false)
        onStatusChange?("Đang xác thực HUD…")
        peripheral.discoverServices([BLEManager.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        writeCharacteristic = nil
        onConnectedChange?(false)
        onStatusChange?("Kết nối thất bại — thử lại…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startScan()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        writeCharacteristic = nil
        onConnectedChange?(false)
        onStatusChange?("Mất kết nối — đang thử lại…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startScan()
        }
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == BLEManager.serviceUUID }) else {
            onConnectedChange?(false)
            onStatusChange?("Không thấy service HUD")
            if peripheral.state == .connected { central.cancelPeripheralConnection(peripheral) }
            return
        }
        peripheral.discoverCharacteristics([BLEManager.writeUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        writeCharacteristic = service.characteristics?.first(where: { $0.uuid == BLEManager.writeUUID })
        if writeCharacteristic != nil, peripheral.state == .connected {
            onConnectedChange?(true)
            onStatusChange?("Đã kết nối HUD ✓")
        } else {
            writeCharacteristic = nil
            onConnectedChange?(false)
            onStatusChange?("Không thấy đặc tính ghi dữ liệu")
            if peripheral.state == .connected { central.cancelPeripheralConnection(peripheral) }
        }
    }
}
