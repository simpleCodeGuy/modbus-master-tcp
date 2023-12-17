import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

typedef Address = ({String ip, int port});
typedef RequestWithTimeStamp = ({
  ModbusRequestData modbusRequestData,
  DateTime timeStampWhenSentToSlave,
});
typedef TransactionId = int;

typedef AddressAndTransactionId = ({
  Address address,
  TransactionId transactionId
});

extension IntegerExtension on int {
  Uint8List get toUint8List1byte {
    return Uint8List.fromList(<int>[this]);
  }

  Uint8List get toUint8List2bytes {
    int msb = this ~/ 256;
    return Uint8List.fromList(<int>[msb, this]);
  }
}

extension Uint8ListExtension on Uint8List {
  int get convertFirstTwoElementsToInteger {
    int msbInteger = this[0];
    int lsbInteger = this[1];

    return msbInteger * 256 + lsbInteger;
  }
}

///modbusMaster is an object of class ModbusMaster
///
///modbusMaster.responses() is a method which returns Stream of Response
///
///Fields of instance of class Response are
///-
///- ipv4: ipv4 address of slave
///- port: port number of slave
///- transactionId: as specified in modbus/tcp protocol
///- isWrite:
///   - for success, value is Response.SUCCESS i.e. true
///   - for failure, value is Resonse.FAIL i.e. false
///- isSuccess:
///   - for success, value is Response.SUCCESS i.e. true
///   - for failure, value is Resonse.FAIL i.e. false
///- readData:
///   - bool value when coil or discrete input is read
///   - int value when holding register or input register is read
///   - null when data is written, or in case of error response
class Response {
  static const bool RESPONSE_TYPE_READ = false;
  static const bool RESPONSE_TYPE_WRITE = true;

  static const bool FAIL = false;
  static const bool SUCCESS = true;

  ///ipv4 address of slave machine
  final String ipv4;

  ///port number of slave machine
  final int port;

  ///transactionId between 0 to 65535, same as transaction id of modbus/tcp
  ///implementation
  final int transactionId;

  ///- for write response, value is Response.RESPONSE_TYPE_WRITE i.e. true
  ///- for read response, value is Response.RESPONSE_TYPE_READ i.e. false
  final bool isWrite;

  ///- for success, value is Response.SUCCESS i.e. true
  ///- for failure, value is Resonse.FAIL i.e. false
  final bool isSuccess;

  ///- bool value when coil or discrete input is read
  ///- int value when holding register or input register is read
  ///- null when data is written, in case of error response
  final dynamic readData;

  ///modbusMaster is an object of class ModbusMaster
  ///
  ///modbusMaster.responses() is a method which returns Stream of Response
  ///
  ///Arguments are
  ///-
  ///- ipv4: ipv4 address of slave
  ///- port: port number of slave
  ///- transactionId: as specified in modbus/tcp protocol
  ///- isWrite:
  ///   - for success, value is Response.SUCCESS i.e. true
  ///   - for failure, value is Resonse.FAIL i.e. false
  ///- isSuccess:
  ///   - for success, value is Response.SUCCESS i.e. true
  ///   - for failure, value is Resonse.FAIL i.e. false
  ///- readData:
  ///   - bool value when coil or discrete input is read
  ///   - int value when holding register or input register is read
  ///   - null when data is written, or in case of error response
  const Response({
    required this.ipv4,
    required this.port,
    required this.transactionId,
    required this.isWrite,
    required this.isSuccess,
    required this.readData,
  });

  static Response fromModbusResponseData(
      ModbusResponseData modbusResponseData) {
    int functionCode = modbusResponseData.pdu[0];
    bool isSuccess = functionCode < 128;
    bool isWrite = false;
    dynamic readData;
    if (isSuccess) {
      switch (functionCode) {
        case 1:
          isWrite = false;
          readData = modbusResponseData.pdu[2] > 0;
          break;
        case 2:
          isWrite = false;
          readData = modbusResponseData.pdu[2] > 0;
          break;
        case 3:
          isWrite = false;
          readData = modbusResponseData.pdu
              .sublist(2, 4)
              .convertFirstTwoElementsToInteger;
          break;
        case 4:
          isWrite = false;
          readData = modbusResponseData.pdu
              .sublist(2, 4)
              .convertFirstTwoElementsToInteger;
          break;
        case 5:
          isWrite = true;
          readData = null;
          break;
        case 6:
          isWrite = true;
          readData = null;
          break;
        default:
          readData = null;
      }
    } else {
      switch (functionCode) {
        case 129:
          isWrite = false;
          readData = null;
          break;
        case 130:
          isWrite = false;
          readData = null;
          break;
        case 131:
          isWrite = false;
          readData = null;
          break;
        case 132:
          isWrite = false;
          readData = null;
          break;
        case 133:
          isWrite = true;
          readData = null;
          break;
        case 134:
          isWrite = true;
          readData = null;
          break;
        default:
          readData = null;
      }
    }

    return Response(
      ipv4: modbusResponseData.ipv4Slave,
      port: modbusResponseData.portSlave,
      transactionId: modbusResponseData.transactionId,
      isWrite: isWrite,
      isSuccess: isSuccess,
      readData: readData,
    );
  }

  @override
  String toString() {
    String successMsg = isSuccess ? 'SUCCESS' : 'FAIL';
    String writeMsg = isWrite ? 'WRITE' : 'READ';
    String readMsg = readData == null ? '' : readData.toString();
    // return 'Response from $ipv4:$port, transactionId=$transactionId, $successMsg, $writeMsg, $readMsg';
    return '<- $ipv4:$port, transactionId=$transactionId, $successMsg, $writeMsg, $readMsg';
  }
}

///Its instance is required for reading or writing from or to
///a modbus slave when 'sendRequest' method of 'object of ModbusMaster' class is used
///
///Read or write can be done by sending an object of Request using method
///- sendRequest
///
///Or, High level Read and Write can be done by 6 methods without using an
///object of Request class
///- readCoil
///- readDiscreteInput
///- readHoldingRegister
///- readInputRegister
///- writeCoil
///- writeHoldingRegister
class Request {
  static const bool REQUEST_READ = false;
  static const bool REQUEST_WRITE = true;

  static const int ELEMENT_TYPE_DISCRETE_INPUT = 1;
  static const int ELEMENT_TYPE_COIL = 2;
  static const int ELEMENT_TYPE_INPUT_REGISTER = 3;
  static const int ELEMENT_TYPE_HOLDING_REGISTER = 4;

  ///ipv4 address of slave machine as string e.g. '195.162.1.2'
  final String ipv4;

  ///port number of slave machine as integer
  ///
  ///port number 502 is recommended for modbus slave,
  ///but if slave device is listening at another port, then that port number
  ///should be specified
  final int port;

  ///transactionId is unique number from 0 to 65535,
  ///
  ///In modbus/tcp implementation, each request has unique transactionId.
  ///This is because, multiple read and write requests can be sent to one modbus
  ///slave without waiting for its response to arrive. Hence, transactionId
  ///identifies that this response belongs to this request.
  final int transactionId;

  ///- Request.REQUEST_READ for read command
  ///- Request.REQUEST_WRITE for write command
  final bool isWrite;

  ///elementType should be one of these four
  ///- Request.ELEMENT_TYPE_DISCRETE_INPUT
  ///- Request.ELEMENT_TYPE_COIL
  ///- Request.ELEMENT_TYPE_INPUT_REGISTER
  ///- Request.ELEMENT_TYPE_HOLDING_REGISTER
  late final int elementType;

  ///elementNumber is an integer whose value should be from 1 to 65536
  late final int elementNumber;

  ///timeout is time within which if response is not received from slave, then
  ///error response is produced. default is 1000ms
  final Duration timeout;

  ///true/false for writing to coil of slave
  ///
  ///integer value from 0 to 65535 for writing to holding register of slave
  ///
  ///For read request, valueToBeWritten should be null
  final dynamic valueToBeWritten;

  ///returns an instance of Request class is required for reading or writing from or to
  ///a modbus slave when 'sendRequest' method is used
  ///
  ///Read or write can be done by sending an object of Request using method
  ///- sendRequest
  ///
  ///Or, High level Read and Write can be done by 6 methods without using an
  ///object of Request class
  ///- readCoil
  ///- readDiscreteInput
  ///- readHoldingRegister
  ///- readInputRegister
  ///- writeCoil
  ///- writeHoldingRegister
  ///
  ///
  ///Arguments of this method
  ///-
  ///-  ipv4 : ipv4 address of Slave
  ///-  port : port number of Slave
  ///-  transactionId:
  ///     - transactionId is unique number from 0 to 65535,
  ///     - In modbus/tcp implementation, each request has unique transactionId.
  ///     This is because, multiple read and write requests can be sent to one
  ///     modbus slave without waiting for its response to arrive. Hence,
  ///     transactionId identifies that this response belongs to this request.
  ///-  isWrite:
  ///     - Request.REQUEST_READ for read command
  ///     - Request.REQUEST_WRITE for write command
  ///-  elementType: elementType should be one of these four
  ///     - Request.ELEMENT_TYPE_DISCRETE_INPUT
  ///     - Request.ELEMENT_TYPE_COIL
  ///     - Request.ELEMENT_TYPE_INPUT_REGISTER
  ///     - Request.ELEMENT_TYPE_HOLDING_REGISTER
  ///-  elementNumber: should be between 1 and 65536, or else throws error
  ///-  valueToBeWritten :
  ///     - bool value for writing to coil of slave
  ///     - int value between 0 and 65536 for writing to holding register
  ///       of slave
  ///     - or null when reading value
  ///     - anything other than this throws exception
  ///-  timeout: time within which if response is not received from slave, then
  ///   error response is produced. default is 1000ms
  Request({
    required this.ipv4,
    this.port = 502,
    required this.transactionId,
    required this.isWrite,
    required int elementType,
    required int elementNumber,
    required this.valueToBeWritten,
    this.timeout = const Duration(milliseconds: 1000),
  }) {
    if (elementType < 1 || elementType > 4) {
      throw Exception('element type is wrong');
    }
    if (elementNumber < 1 || elementNumber > 65536) {
      throw Exception('element number should be between 1 and 65536');
    }
    if (!isWrite && valueToBeWritten != null) {
      throw Exception(
          'non-null value is provided in valueToBeWritten while reading');
    }
    if (isWrite) {
      if (elementType == Request.ELEMENT_TYPE_COIL &&
          valueToBeWritten.runtimeType != bool) {
        throw Exception('attemped to write value other than bool to a coil');
      } else if (elementType == Request.ELEMENT_TYPE_HOLDING_REGISTER) {
        if (valueToBeWritten.runtimeType != int) {
          throw Exception(
              'attemped to write value other than int to a holding register');
        } else if (valueToBeWritten < 0 || valueToBeWritten > 65535) {
          throw Exception(
              'attemped to write value out of range from 0 to 65535');
        }
      }
    }

    this.elementType = elementType;
    this.elementNumber = elementNumber;
  }

  @override
  String toString() {
    // String successMsg = isSuccess ? 'SUCCESS' : 'FAIL';
    String writeMsg = isWrite ? 'WRITE' : 'READ';

    String elementTypeMsg;
    switch (elementType) {
      case Request.ELEMENT_TYPE_COIL:
        elementTypeMsg = 'COIL';
        break;
      case Request.ELEMENT_TYPE_DISCRETE_INPUT:
        elementTypeMsg = 'DISCRETE INPUT';
        break;
      case Request.ELEMENT_TYPE_HOLDING_REGISTER:
        elementTypeMsg = 'HOLDING REGISTER';
        break;
      case Request.ELEMENT_TYPE_INPUT_REGISTER:
        elementTypeMsg = 'INPUT REGISTER';
        break;
      default:
        elementTypeMsg = 'OTHER ELEMENT';
    }

    // String elementNumberMsg = elementNumber.toString();
    String valueToBeWrittenMsg =
        valueToBeWritten == null ? '' : valueToBeWritten.toString();
    // return '-> Request to $ipv4:$port, transactionId=$transactionId, '
    //     '$writeMsg, $elementTypeMsg#$elementNumber, $valueToBeWrittenMsg';
    return '-> $ipv4:$port, transactionId=$transactionId, '
        '$writeMsg, $elementTypeMsg#$elementNumber, $valueToBeWrittenMsg';
  }
}

class ModbusRequestData {
  final String ipv4Slave;
  final int portSlave;
  final Duration timeout;
  final int transactionId;
  final Uint8List pdu;

  const ModbusRequestData({
    required this.ipv4Slave,
    required this.transactionId,
    required this.pdu,
    this.portSlave = 502,
    this.timeout = const Duration(milliseconds: 1000),
  });

  ModbusRequestData get copy => ModbusRequestData(
        ipv4Slave: ipv4Slave,
        transactionId: transactionId,
        pdu: pdu,
        portSlave: portSlave,
        timeout: timeout,
      );

  Address get address {
    Address adr;
    adr = (ip: ipv4Slave, port: portSlave);
    return adr;
  }

  Uint8List get modbusTcpAdu {
    Uint8List transId = transactionId.toUint8List2bytes;
    Uint8List protocolIdentifier = 0.toUint8List2bytes;
    Uint8List len = (1 + pdu.length).toUint8List2bytes;
    Uint8List unitIdentifier = Uint8List.fromList([0]);
    Uint8List adu = Uint8List.fromList(
        transId + protocolIdentifier + len + unitIdentifier + pdu);
    return adu;
  }

  static ModbusRequestData get dummy {
    return ModbusRequestData(
      ipv4Slave: '0.0.0.0',
      transactionId: 1,
      pdu: Uint8List.fromList([]),
    );
  }

  @override
  String toString() {
    return '$ipv4Slave:$portSlave, transactionId=$transactionId, timeout=$timeout, request pdu=$pdu\n';
  }

  static ModbusRequestData fromRequest(Request request) {
    ModbusRequestData modbusRequestData;
    Uint8List functionCode;
    Uint8List firstCoilAddress;
    Uint8List coilCount;
    Uint8List registerCount;
    Uint8List coilValue;
    Uint8List pduBytes;

    ModbusRequestData _readCoil() {
      functionCode = 1.toUint8List1byte;
      firstCoilAddress = (request.elementNumber - 1).toUint8List2bytes;
      coilCount = (1).toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + coilCount);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.ipv4,
        transactionId: request.transactionId,
        pdu: pduBytes,
        portSlave: request.port,
        timeout: request.timeout,
      );
      return modbusRequestData;
    }

    ModbusRequestData _readDiscreteInput() {
      functionCode = 2.toUint8List1byte;
      firstCoilAddress = (request.elementNumber - 1).toUint8List2bytes;
      coilCount = 1.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + coilCount);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.ipv4,
        transactionId: request.transactionId,
        pdu: pduBytes,
        portSlave: request.port,
        timeout: request.timeout,
      );
      return modbusRequestData;
    }

    ModbusRequestData _readHoldingRegister() {
      functionCode = 3.toUint8List1byte;
      firstCoilAddress = (request.elementNumber - 1).toUint8List2bytes;
      registerCount = 1.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + registerCount);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.ipv4,
        transactionId: request.transactionId,
        pdu: pduBytes,
        portSlave: request.port,
        timeout: request.timeout,
      );
      return modbusRequestData;
    }

    ModbusRequestData _readInputRegister() {
      functionCode = 4.toUint8List1byte;
      firstCoilAddress = (request.elementNumber - 1).toUint8List2bytes;
      registerCount = 1.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + registerCount);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.ipv4,
        transactionId: request.transactionId,
        pdu: pduBytes,
        portSlave: request.port,
        timeout: request.timeout,
      );
      return modbusRequestData;
    }

    ModbusRequestData _writeCoil() {
      functionCode = 5.toUint8List1byte;
      firstCoilAddress = (request.elementNumber - 1).toUint8List2bytes;

      coilValue = request.valueToBeWritten
          ? 65280.toUint8List2bytes
          : 0.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + coilValue);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.ipv4,
        transactionId: request.transactionId,
        pdu: pduBytes,
        portSlave: request.port,
        timeout: request.timeout,
      );

      return modbusRequestData;
    }

    ModbusRequestData _writeHoldingRegister() {
      functionCode = 6.toUint8List1byte;
      firstCoilAddress = (request.elementNumber - 1).toUint8List2bytes;

      coilValue = request.valueToBeWritten.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + coilValue);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.ipv4,
        transactionId: request.transactionId,
        pdu: pduBytes,
        portSlave: request.port,
        timeout: request.timeout,
      );

      return modbusRequestData;
    }

    bool validRequest = true;

    switch (request.isWrite) {
      case Request.REQUEST_READ:
        switch (request.elementType) {
          case Request.ELEMENT_TYPE_COIL:
            modbusRequestData = _readCoil();

            break;

          case Request.ELEMENT_TYPE_DISCRETE_INPUT:
            modbusRequestData = _readDiscreteInput();
            break;

          case Request.ELEMENT_TYPE_HOLDING_REGISTER:
            modbusRequestData = _readHoldingRegister();
            break;

          case Request.ELEMENT_TYPE_INPUT_REGISTER:
            modbusRequestData = _readInputRegister();
            break;

          default:
            modbusRequestData = ModbusRequestData.dummy;
            validRequest = false;
        }
        break;
      case Request.REQUEST_WRITE:
        switch (request.elementType) {
          case Request.ELEMENT_TYPE_COIL:
            modbusRequestData = _writeCoil();
            break;
          case Request.ELEMENT_TYPE_HOLDING_REGISTER:
            modbusRequestData = _writeHoldingRegister();
            break;
          default:
            modbusRequestData = ModbusRequestData.dummy;
            validRequest = false;
        }
        break;
    }

    if (!validRequest) {
      throw Exception('wrong request');
    }

    // return getRequest[request.isWrite]![request.elementType] ??
    //     ModbusRequestData.dummy;

    return modbusRequestData;
  }
}

class ModbusResponseData {
  final String ipv4Slave;
  final int portSlave;
  final int transactionId;
  final Uint8List pdu;

  const ModbusResponseData({
    required this.ipv4Slave,
    required this.portSlave,
    required this.transactionId,
    required this.pdu,
  });

  ModbusResponseData get copy => ModbusResponseData(
        ipv4Slave: ipv4Slave,
        portSlave: portSlave,
        transactionId: transactionId,
        pdu: pdu,
      );

  Address get address {
    Address adr;
    adr = (ip: ipv4Slave, port: portSlave);
    return adr;
  }

  static ModbusResponseData generateResponseFrom({
    required Address address,
    required Uint8List responseAdu,
  }) {
    Uint8List transactionIdAsTwoBytes = responseAdu.sublist(0, 2);
    int transactionIdentifier =
        transactionIdAsTwoBytes.convertFirstTwoElementsToInteger;

    Uint8List responsePdu = responseAdu.sublist(7);

    return ModbusResponseData(
      ipv4Slave: address.ip,
      portSlave: address.port,
      transactionId: transactionIdentifier,
      pdu: responsePdu,
    );
  }

  @override
  String toString() =>
      '$ipv4Slave:$portSlave, transactionId=$transactionId, pdu=$pdu';
}

class AliveConnections {
  final Map<Address, Socket> _data = {};

  void removeAddress(Address address) {
    _data.remove(address);
  }

  Socket? socketAt(Address address) {
    return _data[address];
  }

  void insert({required Socket socket, required Address atAddress}) {}

  bool hasAddress(Address address) {
    bool addressFound = false;
    for (Address addressAlive in _data.keys) {
      if (address == addressAlive) {
        addressFound = true;
        break;
      }
    }
    return addressFound;
  }

  bool isEmpty() {
    return _data.isEmpty;
  }

  void copy({required dynamic copyTo, required Address atAddress}) {
    if (copyTo.runtimeType == RequestWithAliveConnection) {
    } else if (copyTo.runtimeType == RequestWithDeadConnection) {}
  }

  void addSocket({required Socket socket, required Address atAddress}) {
    _data[atAddress] = socket;
  }

  void destroyAllSocketsAndClear() {
    List<Socket> sockets = [];

    sockets = _data.values.toList();

    for (Socket socket in sockets) {
      socket.destroy();
    }

    _data.clear();
  }

  int length() => _data.length;

  void destroyEarliestConnection() {
    if (_data.isNotEmpty) {
      Address address = _data.keys.first;
      _data[address]!.destroy();
    }
  }

  @override
  String toString() {
    // TODO: implement toString
    // return super.toString();
    String msg = 'Socket: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port}, ';
    }
    return msg;
  }
}

class Requests {
  final List<ModbusRequestData> _data = [];

  bool isEmpty() {
    return _data.isEmpty;
  }

  int get length => _data.length;

  // ModbusRequestData elementAt(int index) => _data[index];

  Address addressAt(int index) => _data[index].address;

  void copy({required int index, required dynamic copyTo}) {
    ModbusRequestData item = _data[index];
    if (copyTo.runtimeType == RequestWithAliveConnection ||
        copyTo.runtimeType == RequestWithDeadConnection) {
      Map<Address, List<ModbusRequestData>> data = copyTo._data;
      Address adr = (ip: item.ipv4Slave, port: item.portSlave);
      if (data[item.address] == null) {
        data[adr] = <ModbusRequestData>[];
      }
      data[adr]!.add(item.copy);
    }
  }

  void clear() => _data.clear();

  void append(ModbusRequestData modbusRequestData) {
    _data.add(modbusRequestData);
  }

  @override
  String toString() {
    String msg = 'Requests:';
    for (ModbusRequestData modbusRequestData in _data) {
      msg = msg + '${modbusRequestData.transactionId},';
    }
    return msg;
  }
}

class RequestWithAliveConnection {
  final Map<Address, List<ModbusRequestData>> _data = {};

  Iterable<Address> addresses() {
    return _data.keys;
  }

  // void sendToSlave({required Address slaveAddress, required}) {}

  void copy({
    required Address atAddress,
    required dynamic to,
  }) {
    if (to.runtimeType == RequestSentToSlave) {
      List<ModbusRequestData>? li;
      li = _data[atAddress];
      if (li != null) {
        for (ModbusRequestData modbusRequestData in li) {
          int transId = modbusRequestData.transactionId;

          if (to._data[atAddress] == null) {
            to._data[atAddress] = <TransactionId, RequestWithTimeStamp>{};
          }
          RequestWithTimeStamp requestWithTimeStamp;

          requestWithTimeStamp = (
            modbusRequestData: modbusRequestData.copy,
            timeStampWhenSentToSlave: DateTime.now()
          );

          to._data[atAddress][transId] = requestWithTimeStamp;
        }
      }
    } else if (to.runtimeType == RequestWithDeadConnection) {
      List<ModbusRequestData>? li;
      li = _data[atAddress];
      Map<Address, List<ModbusRequestData>> data = to._data;
      if (li != null) {
        for (ModbusRequestData modbusRequestData in li) {
          if (data[atAddress] == null) {
            data[atAddress] = <ModbusRequestData>[];
          }
          data[atAddress]!.add(modbusRequestData.copy);
        }
      }
    }
  }

  void eraseAtAddress(Address address) {
    _data.remove(address);
  }

  void clear() => _data.clear();

  bool isEmpty() => _data.isEmpty;

  void sendToSlave({
    required Address atAddress,
    required AliveConnections aliveConnections,
  }) {
    List<ModbusRequestData>? modbusRequestDatas;
    modbusRequestDatas = _data[atAddress];

    if (modbusRequestDatas != null) {
      for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
        String msg = String.fromCharCodes(modbusRequestData.modbusTcpAdu);

        aliveConnections.socketAt(atAddress)!.write(msg);
      }
    }
  }

  @override
  String toString() {
    String msg = 'Request Alive: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port} [';
      List<ModbusRequestData>? modbusRequestDatas = _data[address];

      if (modbusRequestDatas != null) {
        for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
          msg = msg + '${modbusRequestData.transactionId},';
        }
      }
      msg = msg + '] ';
    }
    return msg;
  }
}

class RequestWithDeadConnection {
  final Map<Address, List<ModbusRequestData>> _data = {};

  Iterable<Address> addresses() {
    return _data.keys;
  }

  void copy({
    required Address atAddress,
    required dynamic to,
  }) {
    if (to.runtimeType == RequestAttemptingToConnect ||
        to.runtimeType == RequestWithAliveConnection) {
      Map<Address, List<ModbusRequestData>> data = to._data;

      List<ModbusRequestData>? modbusRequestDatas = _data[atAddress];
      if (modbusRequestDatas != null) {
        for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
          if (data[atAddress] == null) {
            data[atAddress] = <ModbusRequestData>[];
          }
          data[atAddress]!.add(modbusRequestData.copy);
        }
      }
    } else {
      throw Exception('data type of "to" argument should be either '
          'RequestAttemptingToConnect or RequestWithAliveConnection');
    }
  }

  void clear() => _data.clear();

  bool isEmpty() => _data.isEmpty;

  @override
  String toString() {
    String msg = 'Request Dead: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port} [';
      List<ModbusRequestData>? modbusRequestDatas = _data[address];

      if (modbusRequestDatas != null) {
        for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
          msg = msg + '${modbusRequestData.transactionId},';
        }
      }
      msg = msg + '] ';
    }
    return msg;
  }
}

class RequestAttemptingToConnect {
  Map<Address, List<ModbusRequestData>> _data = {};

  List<Address> addresses() {
    List<Address> addresses = [];
    for (Address address in _data.keys) {
      addresses.add(address);
    }
    return addresses;
  }

  void copy({
    required Address atAddress,
    required RequestWithAliveConnection to,
  }) {
    if (to._data[atAddress] == null) {
      to._data[atAddress] = <ModbusRequestData>[];
    }

    List<ModbusRequestData> li = [];

    List<ModbusRequestData>? listOfRequestData = _data[atAddress];
    if (listOfRequestData != null) {
      for (ModbusRequestData modbusRequestData in listOfRequestData) {
        li.add(modbusRequestData.copy);
      }
    }

    to._data[atAddress]?.addAll(li);
  }

  void eraseAtAddress(Address address) {
    _data.remove(address);
  }

  bool isEmpty() => _data.isEmpty;

  List<ModbusResponseData> getConnectionNotEstablishedErrorResponse(
      {required Address atAddress}) {
    List<ModbusRequestData>? modbusRequestDatas = _data[atAddress];
    List<ModbusResponseData> modbusResponseDatas = [];

    // print('TRYING TO GET ERROR RESPONSE AT ADDRESS ${atAddress}');

    if (modbusRequestDatas == null) {
      throw Exception('trying to access address, whose entry does not exist.');
    } else {
      for (var modbusRequestData in modbusRequestDatas) {
        List<int> responsePduAsInt = [128 + modbusRequestData.pdu[0], 4];
        Uint8List responsePdu = Uint8List.fromList(responsePduAsInt);

        modbusResponseDatas.add(
          ModbusResponseData(
            ipv4Slave: modbusRequestData.ipv4Slave,
            portSlave: modbusRequestData.portSlave,
            transactionId: modbusRequestData.transactionId,
            pdu: responsePdu,
          ),
        );
      }
    }

    return modbusResponseDatas;
  }

  @override
  String toString() {
    String msg = 'Request Attempting to Connect: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port} [';
      List<ModbusRequestData>? modbusRequestDatas = _data[address];

      if (modbusRequestDatas != null) {
        for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
          msg = msg + '${modbusRequestData.transactionId},';
        }
      }
      msg = msg + '] ';
    }
    return msg;
  }
}

class RequestSentToSlave {
  Map<Address, Map<TransactionId, RequestWithTimeStamp>> _data = {};

  List<AddressAndTransactionId> getIdentifier() {
    List<AddressAndTransactionId> identifiers = [];
    for (Address address in _data.keys) {
      for (TransactionId transactionId in _data[address]!.keys) {
        AddressAndTransactionId identifier =
            (address: address, transactionId: transactionId);
        identifiers.add(identifier);
      }
    }
    return identifiers;
  }

  bool hasIdentifier(AddressAndTransactionId id) {
    Address address = id.address;
    int transactionId = id.transactionId;

    bool found = false;

    if (_data[address] != null) {
      if (_data[address]![transactionId] != null) {
        found = true;
      }
    }

    return found;
  }

  bool hasTimeoutExceededOf(AddressAndTransactionId identifier) {
    RequestWithTimeStamp? requestWithTimeStamp =
        _data[identifier.address]![identifier.transactionId];

    bool timeOutExceeded = false;

    if (requestWithTimeStamp != null) {
      Duration timeDifference = DateTime.now()
          .difference(requestWithTimeStamp.timeStampWhenSentToSlave);

      if (timeDifference > requestWithTimeStamp.modbusRequestData.timeout) {
        timeOutExceeded = true;
      }
    }
    return timeOutExceeded;
  }

  ModbusRequestData getModbusRequestData(AddressAndTransactionId identifier) {
    return _data[identifier.address]![identifier.transactionId]!
        .modbusRequestData
        .copy;
  }

  void erase(AddressAndTransactionId identifier) {
    _data[identifier.address]!.remove(identifier.transactionId);
    if (_data[identifier.address]!.isEmpty) {
      _data.remove(identifier.address);
    }

    // try {
    //   getModbusRequestData(identifier);

    //   print('NOT ERASED');
    // } catch (_, __) {
    //   print('ERASED');
    // }
  }

  bool isEmpty() => _data.isEmpty;

  ModbusResponseData getErrorResponseDueToTimeout(
    AddressAndTransactionId identifier,
  ) {
    Address address = identifier.address;
    TransactionId transactionId = identifier.transactionId;
    ModbusRequestData? modbusRequestData;
    ModbusResponseData modbusResponseData;

    if (_data[address] == null) {
      throw Exception('trying to access address, whose entry does not exist.');
    } else {
      if (_data[address]![transactionId] == null) {
        throw Exception(
            'trying to access address, whose entry does not exist.');
      } else {
        modbusRequestData = _data[address]?[transactionId]?.modbusRequestData;

        List<int> responsePduAsInt = [128 + modbusRequestData!.pdu[0], 6];
        Uint8List responsePdu = Uint8List.fromList(responsePduAsInt);

        modbusResponseData = ModbusResponseData(
          ipv4Slave: address.ip,
          portSlave: address.port,
          transactionId: transactionId,
          pdu: responsePdu,
        );
      }
    }

    return modbusResponseData;
  }

  @override
  String toString() {
    String msg = 'Request Sent to Slave: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port} ';

      for (TransactionId transactionId in _data[address]!.keys) {
        msg = msg +
            '$transactionId(${_data[address]![transactionId]!.timeStampWhenSentToSlave})';
      }
    }
    return msg;
  }
}

class ResponseReceivedFromSlave {
  Map<Address, Map<TransactionId, ModbusResponseData>> _data = {};

  List<AddressAndTransactionId> getIdentifiers() {
    List<AddressAndTransactionId> identifiers = [];
    for (Address address in _data.keys) {
      for (TransactionId transactionId in _data[address]!.keys) {
        AddressAndTransactionId identifier =
            (address: address, transactionId: transactionId);
        identifiers.add(identifier);
      }
    }
    return identifiers;
  }

  bool isFound({
    required AddressAndTransactionId atAddressAndTransactionId,
    required RequestSentToSlave inRequestSentToSlave,
  }) {
    bool found = false;

    if (inRequestSentToSlave._data[atAddressAndTransactionId.address] != null) {
      if (inRequestSentToSlave._data[atAddressAndTransactionId.address]![
              atAddressAndTransactionId.transactionId] !=
          null) {
        found = true;
      }
    }

    return found;
  }

  ModbusResponseData? getElementAt(AddressAndTransactionId id) {
    Address address = id.address;
    int transactionId = id.transactionId;

    return _data[address]?[transactionId];
  }

  void clear() {
    _data.clear();
  }

  bool isEmpty() => _data.isEmpty;

  void append({
    required Uint8List modbusTcpAdu,
    required Address atAddress,
  }) {
    ModbusResponseData modbusResponseData =
        ModbusResponseData.generateResponseFrom(
      address: atAddress,
      responseAdu: modbusTcpAdu,
    );

    if (_data[atAddress] == null) {
      _data[atAddress] = <TransactionId, ModbusResponseData>{};
    }

    _data[atAddress]![modbusResponseData.transactionId] =
        modbusResponseData.copy;
  }

  @override
  String toString() {
    String msg = 'Response: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port} ';

      for (TransactionId transactionId in _data[address]!.keys) {
        msg = msg + '$transactionId,';
      }
    }
    return msg;
  }
}

class ModbusMaster {
  late final Duration
      socketConnectionTimeout; // = Duration(milliseconds: 2000);
  static const int maximumSlaveConnectionsAtOneTime = 247;

  final _streamController = StreamController<ModbusResponseData>();

  final _aliveConnections = AliveConnections();
  final List<Address> _addressTryingToConnect = [];

  final _requests = Requests();
  final _requestWithAliveConnection = RequestWithAliveConnection();
  final _requestWithDeadConnection = RequestWithDeadConnection();
  final _requestSentToSlave = RequestSentToSlave();
  final _requestAttemptingToConnect = RequestAttemptingToConnect();
  final _responseReceivedFromSlave = ResponseReceivedFromSlave();
  bool _loopRunning = false;
  bool _closeRequested = false;
  int _countOfRequestForWhichResponsesNotReceived = 0;

  ///## Steps to use this library:
  ///-   make an instance of ModbusMaster class
  ///    -   modbusMaster = ModbusMaster()
  ///-   intitiate modbus master object
  ///    -   modbusMaster.start()
  ///-   listen to stream of response using stream
  ///    -   modbusMaster.responses().listen()
  ///-   Send request to slave
  ///    -   using low level method
  ///        - modbusMaster.sendRequest(request)
  ///    -   using high level method
  ///        -   read single coil
  ///            -   modbusMaster.readCoil()
  ///        -   read single discrete input of a slave
  ///            -   modbusMaster.readDiscreteInput()
  ///        -   read single holding register of a slave
  ///            - modbusMaster.readHoldingRegister()
  ///        -   read single input register of a slave
  ///            - modbusMaster.readInputRegister()
  ///        -   to write single coil of a slave
  ///            - modbusMaster.writeCoil()
  ///        -   write single holding register of a slave
  ///            - modbusMaster.writeHoldingRegister()
  ///-   close must be called at end to close all tcp connection and stop modbus master
  ///    - modbusMaster.close()
  ///
  ///
  ///## Working of this library:
  ///- for each request, a response is always generated
  ///    - as per timeout, if response is not received from slave device, an error response is generated by library and is put to "responses()" stream
  ///- if close method is executed by server, then first all pending requests are processed and their responses are generated, only then all connections are closed
  ///- If a connection is established with a slave, this master keeps it connected
  ///    - until slave disconnects, or
  ///    - until close() method is called by master, or
  ///    - new connection is tried to be established, when there are already 247 active connections
  ///- If connection is broken, and master is still working,
  ///    - When new request is sent, then master again tries for connection
  ///
  ///## Timeout:
  ///An error response is produced by master, if slave does not reply with a response within specific time
  ///- If master receives response from slave after timeout, then that response is trashed. Because master has already produced an error response for the same.
  ///- each request has a field timeout (default 1000ms)
  ///- ModbusMaster instance has field socketConnectionTimeout (default 2000ms)
  ///- if slave is already connected,
  ///    - if response is not produced within timeout(default 1000ms),
  ///        - master produces error response
  ///- if slave is not connected,
  ///    - master tries for socket connection
  ///    - if connection is not established within socketConnectionTimeout(default 2000 ms)
  ///        - master produces error response
  ///    - if connection is established
  ///        -   if response is not produced within timeout (default 1000ms)
  ///            - master produces error response
  ///- Maximum time taken for producing error response is
  ///    - socketConnectionTimeout(default 2000 ms) + timeout(default 1000ms)
  ///
  ///## Limitations
  ///- works with only ipv4, ipv6 is not supported
  ///- only 247 slaves can be connected at one time,
  ///    - when more than 247 slave is connected, oldest slave connection is broken
  ///- Only single element can be read at once, reading multiple coils or multiple registers is not implemented, although reading multiple elements is specified in modbus/tcp implementation
  ///- Only single element can be written to at once, writing to multiple coils or to multiple registers is not implemented, although writing to multiple elements is specified in modbus/tcp implementation
  ///- works with dart 3.0 and above because it uses dart records
  ///
  ///## Sample Code
  ///
  ///```
  /// void main(List<String> arguments) async {
  ///    final modbusMaster = modbus_client.ModbusMaster();
  ///
  ///    // initiate master
  ///    modbusMaster.start();
  ///
  ///    // listening to response sent by various slaves
  ///    // if 3 responses are received, then close modbusMaster
  ///    int countResponseReceived = 0;
  ///    modbusMaster.responses().listen(
  ///        (response) {
  ///            ++countResponseReceived;
  ///            print(response);
  ///            if (countResponseReceived >= 3) {
  ///                modbusMaster.close();
  ///            }
  ///        },
  ///        onDone: () {
  ///            print('stream has sent done');
  ///        },
  ///    );
  ///
  ///    // send five read holding register request to slave
  ///    // to read holding register #11 at '192.168.1.5':502
  ///    int count = 1;
  ///
  ///    while (count <= 5) {
  ///        try{
  ///            modbusMaster.readHoldingRegister(
  ///                ipv4: '192.168.1.5',
  ///                portNo: 502,
  ///                transactionIdZeroTo65535: count,
  ///                elementNumberOneTo65536: 11,
  ///            );
  ///        }
  ///        catch(e,f){
  ///            print(e);
  ///        }
  ///
  ///        await Future.delayed(Duration(seconds: 2));
  ///        ++count;
  ///    }
  ///}
  ///```
  ModbusMaster({
    this.socketConnectionTimeout = const Duration(milliseconds: 2000),
  });

  /**
   * inititated modbus master object
   */
  void start() async {
    _loopRunning = true;
    //infinite loop
    while (true) {
      _processRequestList();
      _processRequestWithAliveConnection();
      _processRequestWithDeadConnection();
      _processRequestAttemptingToConnect();
      _processResponseReceivedFromSlave();
      _checkTimeoutOfRequestSentToSlave();
      await Future.delayed(Duration.zero);

      // print(
      //     '\n---------------------------------------------------------------------');
      // print(_aliveConnections);
      // print(_requests);
      // print(_requestWithAliveConnection);
      // print(_requestWithDeadConnection);
      // print(_requestAttemptingToConnect);
      // print(_requestSentToSlave);
      // print(_responseReceivedFromSlave);
      // print('Close requested : $_closeRequested');
      // print('Addresses trying to connect: $_addressTryingToConnect');
      // print(
      //     'Count of Request for which response not received: $_countOfRequestForWhichResponsesNotReceived');
      // print(
      //     '---------------------------------------------------------------------\n');

      // if (_closeRequested &&
      //     _requests.isEmpty() &&
      //     _requestWithAliveConnection.isEmpty() &&
      //     _requestWithDeadConnection.isEmpty() &&
      //     _requestSentToSlave.isEmpty() &&
      //     _requestAttemptingToConnect.isEmpty() &&
      //     _responseReceivedFromSlave.isEmpty()) {
      //   print('breaking loop');
      //   break;
      // }

      if (_closeRequested && _countOfRequestForWhichResponsesNotReceived == 0) {
        break;
      }
    }
    _loopRunning = false;

    //  DESTROY ALL SOCKETS AND CLEAR
    _aliveConnections.destroyAllSocketsAndClear();

    _streamController.close();
  }

  ///close must be called at end to close all tcp connection and stop modbus master
  void close() {
    _closeRequested = true;
  }

  void _processRequestList() {
    for (int i = 0; i < _requests.length; ++i) {
      if (_aliveConnections.hasAddress(_requests.addressAt(i))) {
        _requests.copy(index: i, copyTo: _requestWithAliveConnection);
      } else {
        _requests.copy(index: i, copyTo: _requestWithAliveConnection);
      }
    }

    _requests.clear();
  }

  void _processRequestWithAliveConnection() {
    for (Address address in _requestWithAliveConnection.addresses()) {
      if (_aliveConnections.hasAddress(address)) {
        // send request to slave
        _requestWithAliveConnection.sendToSlave(
          atAddress: address,
          aliveConnections: _aliveConnections,
        );

        _requestWithAliveConnection.copy(
          atAddress: address,
          to: _requestSentToSlave,
        );
      } else {
        _requestWithAliveConnection.copy(
          atAddress: address,
          to: _requestWithDeadConnection,
        );
      }
    }

    _requestWithAliveConnection.clear();
  }

  void _processRequestWithDeadConnection() {
    for (Address address in _requestWithDeadConnection.addresses()) {
      if (_aliveConnections.hasAddress(address)) {
        _requestWithDeadConnection.copy(
          atAddress: address,
          to: _requestWithAliveConnection,
        );
      } else {
        _requestWithDeadConnection.copy(
          atAddress: address,
          to: _requestAttemptingToConnect,
        );
      }
    }

    _requestWithDeadConnection.clear();
  }

  void _processRequestAttemptingToConnect() {
    for (Address address in _requestAttemptingToConnect.addresses()) {
      if (!_addressTryingToConnect.contains(address)) {
        _connectToSocketAndSendData(address);
      }
    }
  }

  void _connectToSocketAndSendData(Address address) async {
    try {
      _addressTryingToConnect.add(address);

      Socket socket = await Socket.connect(
        address.ip,
        address.port,
        timeout: socketConnectionTimeout,
      );

      socket.listen(
        (uint8List) {
          _responseReceivedFromSlave.append(
            modbusTcpAdu: uint8List,
            atAddress: address,
          );
        },
        onError: (_) {
          socket.destroy();
        },
        onDone: () {
          socket.close();

          _aliveConnections.removeAddress(address);
        },
      );

      if (_aliveConnections.length() >
          ModbusMaster.maximumSlaveConnectionsAtOneTime) {
        _aliveConnections.destroyEarliestConnection();
      }

      _aliveConnections.addSocket(socket: socket, atAddress: address);

      _requestAttemptingToConnect.copy(
        atAddress: address,
        to: _requestWithAliveConnection,
      );
    } catch (_, __) {
      List<ModbusResponseData> modbusResponseDatas = _requestAttemptingToConnect
          .getConnectionNotEstablishedErrorResponse(atAddress: address);

      for (ModbusResponseData modbusResponseData in modbusResponseDatas) {
        --_countOfRequestForWhichResponsesNotReceived;
        _streamController.sink.add(modbusResponseData);
      }
    }

    _addressTryingToConnect.remove(address);

    _requestAttemptingToConnect.eraseAtAddress(address);
  }

  void _processResponseReceivedFromSlave() {
    for (AddressAndTransactionId id
        in _responseReceivedFromSlave.getIdentifiers()) {
      if (_requestSentToSlave.hasIdentifier(id)) {
        ModbusResponseData? modbusResponseData =
            _responseReceivedFromSlave.getElementAt(id);

        if (modbusResponseData != null) {
          --_countOfRequestForWhichResponsesNotReceived;
          _streamController.sink.add(modbusResponseData);
        }

        // print('TRYING TO ERASE RESPONSE_RECEIVED_FROM_SLAVE');
        _requestSentToSlave.erase(id);
      }
    }

    _responseReceivedFromSlave.clear();
  }

  void _checkTimeoutOfRequestSentToSlave() {
    for (AddressAndTransactionId identifier
        in _requestSentToSlave.getIdentifier()) {
      if (_requestSentToSlave.hasTimeoutExceededOf(identifier)) {
        // print('TIMEOUT EXCEEDED');
        // SEND ERROR RESPONSE TO STREAM, DUE TO RESPONSE NOT RECEIVED IN TIME
        --_countOfRequestForWhichResponsesNotReceived;
        _streamController.sink.add(
          _requestSentToSlave.getErrorResponseDueToTimeout(identifier),
        );

        // DELETE AT IDENTIFIER
        _requestSentToSlave.erase(identifier);
        // print(_requestSentToSlave._data.length);
      }
    }
  }

  ///returns a Stream of Response. All responses from every slave is received
  ///from here.
  ///
  ///It can be used like example given below.
  ///
  ///     modbusMaster.responses().listen(
  ///       (response){
  ///         print(response);
  ///       }
  ///     );
  Stream<Response> responses() {
    if (!_loopRunning || _closeRequested) {
      throw Exception(
          '"getResponse" is called, either before "start", or after "close"');
    }
    return _streamController.stream.map((modbusResponseData) {
      return Response.fromModbusResponseData(modbusResponseData);
    });
  }

  ///request is sent to a slave using this method, for example
  ///```
  /// sendRequest(Request(
  ///   ipv4: '192.168.1.5',
  ///   transactionId: 1,
  ///   isWrite: Request.REQUEST_READ,
  ///   elementType: Request.ELEMENT_TYPE_HOLDING_REGISTER,
  ///   elementNumber: 1,
  ///   valueToBeWritten: null,
  /// ));
  ///```
  ///#### Alternatively, high level methods are there to send requests. These are:
  ///-  readCoil
  ///-  readDiscreteInput
  ///-  readHoldingRegister
  ///-  readInputRegister
  ///-  writeCoil
  ///-  writeHoldingRegister
  void sendRequest(Request request, {bool printRequest = false}) async {
    if (!_loopRunning || _closeRequested) {
      throw Exception(
          '"sendRequest" is called, either before "start", or after "close"');
    }
    if (printRequest) {
      print(request);
    }
    // _requests.addLast(_modbusRequestDataFromRequest(request));

    ++_countOfRequestForWhichResponsesNotReceived;
    _requests.append(ModbusRequestData.fromRequest(request));

    await Future.delayed(Duration.zero);
    // print(_requests);
  }

  ///To read single discrete input of a slave
  ///```
  /// modbusMaster.readDiscreteInput(
  ///   ipv4: '192.168.1.5',
  ///   transactionIdZeroTo65535: 1,
  ///   elementNumberOneTo65536: 11,
  /// );
  /// ```
  void readDiscreteInput({
    required String ipv4,
    int portNo = 502,
    required int transactionIdZeroTo65535,
    required int elementNumberOneTo65536,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    sendRequest(
      Request(
        ipv4: ipv4,
        port: portNo,
        transactionId: transactionIdZeroTo65535,
        isWrite: Request.REQUEST_READ,
        elementType: Request.ELEMENT_TYPE_DISCRETE_INPUT,
        elementNumber: elementNumberOneTo65536,
        valueToBeWritten: null,
        timeout: timeout,
      ),
      printRequest: printRequest,
    );
  }

  ///To read single coil of a slave
  ///```
  /// modbusMaster.readCoil(
  ///   ipv4: '192.168.1.5',
  ///   transactionIdZeroTo65535: 1,
  ///   elementNumberOneTo65536: 11,
  /// );
  /// ```
  void readCoil({
    required String ipv4,
    int portNo = 502,
    required int transactionIdZeroTo65535,
    required int elementNumberOneTo65536,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    sendRequest(
      Request(
        ipv4: ipv4,
        port: portNo,
        transactionId: transactionIdZeroTo65535,
        isWrite: Request.REQUEST_READ,
        elementType: Request.ELEMENT_TYPE_COIL,
        elementNumber: elementNumberOneTo65536,
        valueToBeWritten: null,
        timeout: timeout,
      ),
      printRequest: printRequest,
    );
  }

  /// To read single input register of a slave
  /// ```
  /// modbusMaster.readInputRegister(
  ///   ipv4: '192.168.1.5',
  ///   transactionIdZeroTo65535: 1,
  ///   elementNumberOneTo65536: 11,
  /// );
  /// ```
  void readInputRegister({
    required String ipv4,
    int portNo = 502,
    required int transactionIdZeroTo65535,
    required int elementNumberOneTo65536,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    sendRequest(
      Request(
        ipv4: ipv4,
        port: portNo,
        transactionId: transactionIdZeroTo65535,
        isWrite: Request.REQUEST_READ,
        elementType: Request.ELEMENT_TYPE_INPUT_REGISTER,
        elementNumber: elementNumberOneTo65536,
        valueToBeWritten: null,
        timeout: timeout,
      ),
      printRequest: printRequest,
    );
  }

  /// To read single holding register of a slave
  /// ```
  /// modbusMaster.readHoldingRegister(
  ///   ipv4: '192.168.1.5',
  ///   transactionIdZeroTo65535: 1,
  ///   elementNumberOneTo65536: 11,
  /// );
  /// ```
  void readHoldingRegister({
    required String ipv4,
    int portNo = 502,
    required int transactionIdZeroTo65535,
    required int elementNumberOneTo65536,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    sendRequest(
      Request(
        ipv4: ipv4,
        port: portNo,
        transactionId: transactionIdZeroTo65535,
        isWrite: Request.REQUEST_READ,
        elementType: Request.ELEMENT_TYPE_HOLDING_REGISTER,
        elementNumber: elementNumberOneTo65536,
        valueToBeWritten: null,
        timeout: timeout,
      ),
      printRequest: printRequest,
    );
  }

  /// To write to a single coil of a slave
  /// ```
  /// modbusMaster.writeCoil(
  ///   ipv4: '192.168.1.5',
  ///   transactionIdZeroTo65535: 1,
  ///   elementNumberOneTo65536: 11,
  ///   valueToBeWritten: true,
  /// );
  /// ```
  void writeCoil({
    required String ipv4,
    int portNo = 502,
    required int transactionIdZeroTo65535,
    required int elementNumberOneTo65536,
    required bool valueToBeWritten,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    sendRequest(
      Request(
        ipv4: ipv4,
        port: portNo,
        transactionId: transactionIdZeroTo65535,
        isWrite: Request.REQUEST_WRITE,
        elementType: Request.ELEMENT_TYPE_COIL,
        elementNumber: elementNumberOneTo65536,
        valueToBeWritten: valueToBeWritten,
        timeout: timeout,
      ),
      printRequest: printRequest,
    );
  }

  /// To write to a single holding register of a slave
  /// ```
  /// modbusMaster.writeHoldingRegister(
  ///   ipv4: '192.168.1.5',
  ///   transactionIdZeroTo65535: 1,
  ///   elementNumberOneTo65536: 11,
  ///   valueToBeWritten: 15525,
  /// );
  /// ```
  void writeHoldingRegister({
    required String ipv4,
    int portNo = 502,
    required int transactionIdZeroTo65535,
    required int elementNumberOneTo65536,
    required int integerValueToBeWrittenZeroTo65535,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    sendRequest(
      Request(
        ipv4: ipv4,
        port: portNo,
        transactionId: transactionIdZeroTo65535,
        isWrite: Request.REQUEST_WRITE,
        elementType: Request.ELEMENT_TYPE_HOLDING_REGISTER,
        elementNumber: elementNumberOneTo65536,
        valueToBeWritten: integerValueToBeWrittenZeroTo65535,
        timeout: timeout,
      ),
      printRequest: printRequest,
    );
  }
}
