package com.G2.SNMP.Trap.Sender;

import java.util.Date;

import org.snmp4j.CommunityTarget;
import org.snmp4j.PDU;
import org.snmp4j.Snmp;
import org.snmp4j.TransportMapping;
import org.snmp4j.mp.SnmpConstants;
import org.snmp4j.smi.IpAddress;
import org.snmp4j.smi.OID;
import org.snmp4j.smi.OctetString;
import org.snmp4j.smi.UdpAddress;
import org.snmp4j.smi.VariableBinding;
import org.snmp4j.transport.DefaultUdpTransportMapping;
import java.io.IOException;
import org.snmp4j.TransportStateReference;

public class TrapSenderVersion2 {

    public static final String community = "public";
    // Sending Trap for sysLocation of RFC1213
    public static final String Oid = ".1.3.6.1.2.1.1.8";
    //IP of Local Host
    public static final String ipAddress = "127.0.0.1";
    //Ideally Port 162 should be used to send receive Trap, any other available Port can be used
    public static final int port = 2162;

    public static void main(String[] args) {
        TrapSenderVersion2 trapV2 = new TrapSenderVersion2();
        trapV2.sendTrap_Version2();
    }

    /* helper to capture udp sending packets. */
    class DefaultUdpTransportMappingCap extends DefaultUdpTransportMapping {
        public DefaultUdpTransportMappingCap() throws IOException {
          super();
        }
        @Override
        public void sendMessage(UdpAddress targetAddress, byte[] message,
                                TransportStateReference tmStateReference)
            throws java.io.IOException
        {
            System.out.printf("  byte len %d ", message.length);
            for (int i=0; i<message.length; i++) {
                if ( (i % 16) == 0 ) { System.out.printf("\n  byte %3d  ", i); }
                if ( (i % 4) == 0 ) { System.out.printf(" "); }
                System.out.printf(" %02x", message[i]);
            }
                System.out.printf("\n");
            super.sendMessage(targetAddress, message, tmStateReference);
        }
    }
    /*receive log:
       Trap Type = -89
       Variables = [1.3.6.1.2.1.1.3.0 = Mon Jul 01 17:43:16 PDT 2013, 
                    1.3.6.1.6.3.1.1.4.1.0 = 1.3.6.1.2.1.1.8, 
                    1.3.6.1.6.3.18.1.3.0 = 127.0.0.1, 
                    1.3.6.1.2.1.1.8 = Major]
     *send log:
        Sending V2 Trap... Check Wheather NMS is Listening or not? 
          byte len 132 

          byte   0    30 81 81 02  01 01 04 06  70 75 62 6c  69 63 a7 74
          byte  16    02 04 15 db  eb fe 02 01  00 02 01 00  30 66 30 28
          byte  32    06 08 2b 06  01 02 01 01  03 00 04 1c  4d 6f 6e 20
          byte  48    4a 75 6c 20  30 31 20 31  37 3a 34 38  3a 32 32 20
          byte  64    50 44 54 20  32 30 31 33  30 15 06 0a  2b 06 01 06
          byte  80    03 01 01 04  01 00 06 07  2b 06 01 02  01 01 08 30
          byte  96    11 06 09 2b  06 01 06 03  12 01 03 00  40 04 7f 00
          byte 112    00 01 30 10  06 07 2b 06  01 02 01 01  08 04 05 4d
          byte 128    61 6a 6f 72
     */
    
    /**
     * This methods sends the V1 trap to the Localhost in port 162
     */
    public void sendTrap_Version2() {
        try {
            // Create Transport Mapping
            TransportMapping transport = new DefaultUdpTransportMappingCap();
            transport.listen();

            // Create Target
            CommunityTarget cTarget = new CommunityTarget();
            cTarget.setCommunity(new OctetString(community));
            cTarget.setVersion(SnmpConstants.version2c);
            cTarget.setAddress(new UdpAddress(ipAddress + "/" + port));
            cTarget.setRetries(2);
            cTarget.setTimeout(5000);

            // Create PDU for V2
            PDU pdu = new PDU();

            // need to specify the system up time
            pdu.add(new VariableBinding(SnmpConstants.sysUpTime,
                    new OctetString(new Date().toString())));
            pdu.add(new VariableBinding(SnmpConstants.snmpTrapOID, new OID(
                    Oid)));
            pdu.add(new VariableBinding(SnmpConstants.snmpTrapAddress,
                    new IpAddress(ipAddress)));

            pdu.add(new VariableBinding(new OID(Oid), new OctetString(
                    "Major")));
            pdu.setType(PDU.NOTIFICATION);

            // Send the PDU
            Snmp snmp = new Snmp(transport);
            System.out.println("Sending V2 Trap... Check Wheather NMS is Listening or not? ");
            snmp.send(pdu, cTarget);
            snmp.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
