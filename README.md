# modbus_master.dart
-   It is a library which consists of only one file "modbus_master.dart"
-   It is used to send requests to modbus slave and receive responses via Modbus/TCP  protocol.


## Index
S.No.|Content
---|-----
1|Steps to use this library
2|Working of this library
3|Timeout
4|Limitations
5|Sample Code

## 1) Steps to use this library
-   make an instance of ModbusMaster class
    -   modbusMaster = ModbusMaster()
-   intitiate modbus master object
    -   modbusMaster.start()
-   listen to stream of response using stream
    -   modbusMaster.responses().listen()
-   Send request to slave
    -   using low level method
        - modbusMaster.sendRequest(request)
    -   using high level method
        -   read single coil
            -   modbusMaster.readCoil()
        -   read single discrete input of a slave
            -   modbusMaster.readDiscreteInput()
        -   read single holding register of a slave    
            - modbusMaster.readHoldingRegister()
        -   read single input register of a slave
            - modbusMaster.readInputRegister()
        -   to write single coil of a slave
            - modbusMaster.writeCoil()
        -   write single holding register of a slave
            - modbusMaster.writeHoldingRegister()
-   close must be called at end to close all tcp connection and stop modbus master
    - modbusMaster.close()


## 2) Working of this library:
- for each request, a response is always generated
    - as per timeout, if response is not received from slave device, an error response is generated by library and is put to "responses()" stream
- if close method is executed by server, then first all pending requests are processed and their responses are generated, only then all connections are closed
- If a connection is established with a slave, this master keeps it connected
    - until slave disconnects, or
    - until close() method is called by master, or
    - new connection is tried to be established, when there are already 247 active connections
- If connection is broken, and master is still working,
    - When new request is sent, then master again tries for connection

## 3) Timeout: 
An error response is produced by master, if slave does not reply with a response within specific time
- If master receives response from slave after timeout, then that response is trashed. Because master has already produced an error response for the same.
- each request has a field timeout (default 1000ms)
- ModbusMaster instance has field socketConnectionTimeout (default 2000ms)
- if slave is already connected,
    - if response is not produced within timeout(default 1000ms),
        - master produces error response
- if slave is not connected,
    - master tries for socket connection
    - if connection is not established within socketConnectionTimeout(default 2000 ms)
        - master produces error response
    - if connection is established
        -   if response is not produced within timeout (default 1000ms)
            - master produces error response
- Maximum time taken for producing error response is
    - socketConnectionTimeout(default 2000 ms) + timeout(default 1000ms)

## 4) Limitations
- works with only ipv4, ipv6 is not supported
- only 247 slaves can be connected at one time,
    - when more than 247 slave is connected, oldest slave connection is broken
- Only single element can be read at once, reading multiple coils or multiple registers is not implemented, although reading multiple elements is specified in modbus/tcp implementation
- Only single element can be written to at once, writing to multiple coils or to multiple registers is not implemented, although writing to multiple elements is specified in modbus/tcp implementation
- works with dart 3.0 and above because it uses dart records

## 5) Sample Code

```
void main(List<String> arguments) async {
    final modbusMaster = modbus_client.ModbusMaster();
    
    // initiate master
    modbusMaster.start();
       
    // listening to response sent by various slaves
    // if 3 responses are received, then close modbusMaster
    int countResponseReceived = 0;
    modbusMaster.responses().listen(
        (response) {
            ++countResponseReceived;
            print(response);
            if (countResponseReceived >= 3) {
                modbusMaster.close();
            }
        },
        onDone: () {
            print('stream has sent done');
        },
    );

    // send five read holding register request to slave
    // to read holding register #11 at '192.168.1.5':502
    int count = 1;
           
    while (count <= 5) {
        try{
            modbusMaster.readHoldingRegister(
                ipv4: '192.168.1.5',
                portNo: 502,
                transactionIdZeroTo65535: count,
                elementNumberOneTo65536: 11,
            );
        }
        catch(e,f){
            print(e);
        }
        
        await Future.delayed(Duration(seconds: 2));
        ++count;
    }
}
```