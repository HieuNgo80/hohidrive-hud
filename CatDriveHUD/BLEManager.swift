import Foundation
import CoreBluetooth

/// BLE transport for the ESP32 HUD firmware.
/// Firmware identifiers verified against ESP32_Navigation_HUD_V9:
/// - Device name: ESP32_Sygic_HUD
/// - Service: DD3F0AD1-6239-4E1F-81F1-91F6C9F01D86
/// - Write characteristic: DD3F0AD3-6239-4E1F-81F1-91F6C9F01D86
final class BLEManager: NSObject {
    static let serviceUUID = CBUUID(string: "DD3F0AD1-6239-4E1F-81F1-91F6C9F01D86")
    static let writeUUID   = CBUUID(string: "DD3F0AD3-6239-4E1F-81F1-91F6C9F01D86")
    static let expectedName = "ESP32_Sygic_HUD"

    var onStatusChange: ((String) -> Void)?
    var onConnectedChange: ((Bool) -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var isScanning = false
    private var reconnectWorkItem: DispatchWorkItem?

    // Reliable chunk queue for packets larger than one ATT write.
    private var reliableQueue: [Data] = []
    private var reliableWriteInProgress = false

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn else {
            setDisconnected("Bluetooth chưa sẵn sàng")
            return
        }
        guard !isScanning else { return }

        reconnectWorkItem?.cancel()
        writeCharacteristic = nil
        reliableQueue.removeAll()
        reliableWriteInProgress = false

        // Reuse an already-connected HUD if iOS still owns the link.
        if let connected = central.retrieveConnectedPeripherals(withServices: [Self.serviceUUID]).first {
            peripheral = connected
            connected.delegate = self
            onConnectedChange?(false)
            onStatusChange?("Đang xác thực HUD…")
            connected.discoverServices([Self.serviceUUID])
            return
        }

        isScanning = true
        peripheral = nil
        onConnectedChange?(false)
        onStatusChange?("Đang tìm HUD…")

        // Scan unfiltered, then validate by service UUID or exact device name.
        // This is more robust on iOS if the 128-bit service UUID ends up in scan response data.
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
    }

    private func scheduleReconnect(_ message: String) {
        stopScan()
        writeCharacteristic = nil
        peripheral = nil
        reliableQueue.removeAll()
        reliableWriteInProgress = false
        setDisconnected(message)

        reconnectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.startScan() }
        reconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    private func setDisconnected(_ message: String) {
        onConnectedChange?(false)
        onStatusChange?(message)
    }

    func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []) else { return }
        sendPacket(data)
    }

    func sendRaw(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        sendPacket(data)
    }

    private func sendPacket(_ data: Data) {
        guard let characteristic = writeCharacteristic,
              let peripheral,
              peripheral.state == .connected else { return }

        let noResponseLimit = peripheral.maximumWriteValueLength(for: .withoutResponse)
        if characteristic.properties.contains(.writeWithoutResponse),
           data.count <= noResponseLimit,
           peripheral.canSendWriteWithoutResponse {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            return
        }

        let withResponseLimit = peripheral.maximumWriteValueLength(for: .withResponse)
        if characteristic.properties.contains(.write), data.count <= withResponseLimit {
            reliableQueue.append(data)
            sendNextReliableWrite()
            return
        }

        // Packet is too large for a single write: use the framing protocol supported by FW V9.1.
        enqueueChunkedJSON(data, mtuPayload: max(20, withResponseLimit))
    }

    private func enqueueChunkedJSON(_ data: Data, mtuPayload: Int) {
        guard writeCharacteristic?.properties.contains(.write) == true else {
            onStatusChange?("HUD không hỗ trợ gói dữ liệu dài")
            return
        }

        let begin = Data("~B:\(data.count)".utf8)
        reliableQueue.append(begin)

        // Reserve bytes for the "~C:" prefix on every chunk.
        let chunkPayload = max(8, mtuPayload - 3)
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkPayload, data.count)
            var chunk = Data("~C:".utf8)
            chunk.append(data.subdata(in: offset..<end))
            reliableQueue.append(chunk)
            offset = end
        }

        reliableQueue.append(Data("~E".utf8))
        sendNextReliableWrite()
    }

    private func sendNextReliableWrite() {
        guard !reliableWriteInProgress,
              !reliableQueue.isEmpty,
              let characteristic = writeCharacteristic,
              let peripheral,
              peripheral.state == .connected else { return }

        reliableWriteInProgress = true
        let next = reliableQueue.removeFirst()
        peripheral.writeValue(next, for: characteristic, type: .withResponse)
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScan()
        case .poweredOff:
            stopScan(); setDisconnected("Bluetooth đang tắt")
        case .unauthorized:
            stopScan(); setDisconnected("Chưa cấp quyền Bluetooth")
        case .unsupported:
            stopScan(); setDisconnected("Thiết bị không hỗ trợ Bluetooth LE")
        default:
            stopScan(); setDisconnected("Bluetooth chưa sẵn sàng")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let nameMatches = peripheral.name == Self.expectedName || advertisedName == Self.expectedName
        let serviceMatches = advertisedServices.contains(Self.serviceUUID)

        guard nameMatches || serviceMatches else { return }

        stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        onConnectedChange?(false)
        onStatusChange?("Đang kết nối HUD…")
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        onConnectedChange?(false)
        onStatusChange?("Đang xác thực HUD…")
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        scheduleReconnect("Kết nối thất bại — đang thử lại…")
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        scheduleReconnect("Mất kết nối — đang thử lại…")
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            scheduleReconnect("Lỗi đọc service HUD: \(error.localizedDescription)")
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            setDisconnected("Không thấy service HUD")
            if peripheral.state == .connected { central.cancelPeripheralConnection(peripheral) }
            return
        }

        peripheral.discoverCharacteristics([Self.writeUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            scheduleReconnect("Lỗi đọc characteristic HUD: \(error.localizedDescription)")
            return
        }

        guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.writeUUID }) else {
            writeCharacteristic = nil
            setDisconnected("Không thấy kênh WRITE của HUD")
            if peripheral.state == .connected { central.cancelPeripheralConnection(peripheral) }
            return
        }

        writeCharacteristic = characteristic
        onConnectedChange?(true)
        onStatusChange?("Đã kết nối HUD ✓")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        reliableWriteInProgress = false
        if let error {
            reliableQueue.removeAll()
            onStatusChange?("Lỗi gửi HUD: \(error.localizedDescription)")
            return
        }
        sendNextReliableWrite()
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        // No queue is kept for short no-response packets; next navigation update will retry naturally.
    }
}
