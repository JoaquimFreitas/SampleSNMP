package com.G2.SNMP.Trap.Sender;

import org.snmp4j.CommunityTarget;
import org.snmp4j.PDU;
import org.snmp4j.PDUv1;
import org.snmp4j.Snmp;
import org.snmp4j.TransportMapping;
import org.snmp4j.mp.SnmpConstants;
import org.snmp4j.smi.IpAddress;
import org.snmp4j.smi.OID;
import org.snmp4j.smi.OctetString;
import org.snmp4j.smi.UdpAddress;
import org.snmp4j.transport.DefaultUdpTransportMapping;
import java.io.IOException;
import org.snmp4j.TransportStateReference;
import org.snmp4j.smi.VariableBinding;

public class TrapSenderVersion1 {

    public static final String community = "public";
    // Sending Trap for sysLocation of RFC1213
    public static final String Oid = ".1.3.6.1.2.1.1.8";
    //IP of Local Host
    public static final String ipAddress = "127.0.0.1";
    //Ideally Port 162 should be used to send receive Trap, any other available Port can be used
    public static final int port = 2162;

    public static void main(String[] args) {
        TrapSenderVersion1 trapV1 = new TrapSenderVersion1();
        trapV1.sendTrap_Version1();
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
    /*rx capture:
        Listening on 127.0.0.1/2162
          byte len 41 
          byte   0    30 27 02 01  00 04 06 70  75 62 6c 69  63 a4 1a 06
          byte  16    07 2b 06 01  02 01 01 08  40 04 7f 00  00 01 02 01
          byte  32    06 02 01 01  43 01 00 30  00
        Received PDU...
        Trap Type = -92
        Variables = []
     * tx capture:
        Sending V1 Trap... Check Wheather NMS is Listening or not? 
          byte len 41 
          byte   0    30 27 02 01  00 04 06 70  75 62 6c 69  63 a4 1a 06
          byte  16    07 2b 06 01  02 01 01 08  40 04 7f 00  00 01 02 01
          byte  32    06 02 01 01  43 01 00 30  00
     * rx with timestamp and one var-binding:
          byte len 65 
          byte   0    30 3f 02 01  00 04 06 70  75 62 6c 69  63 a4 32 06
          byte  16    07 2b 06 01  02 01 01 08  40 04 7f 00  00 01 02 01
          byte  32    06 02 01 01  43 02 12 34  30 17 30 15  06 0a 2b 06
          byte  48    01 06 03 01  01 04 01 00  06 07 2b 06  01 02 01 01
          byte  64    08
        Received PDU...
        Trap Type = -92
        Variables = [1.3.6.1.6.3.1.1.4.1.0 = 1.3.6.1.2.1.1.8]
     * 
     */
    /**
     * This methods sends the V1 trap to the Localhost in port 162
     */
    public void sendTrap_Version1() {
        try {
            // Create Transport Mapping
            TransportMapping transport = new DefaultUdpTransportMappingCap();
            transport.listen();

            // Create Target
            CommunityTarget cTarget = new CommunityTarget();
            cTarget.setCommunity(new OctetString(community));
            cTarget.setVersion(SnmpConstants.version1);
            cTarget.setAddress(new UdpAddress(ipAddress + "/" + port));
            cTarget.setTimeout(5000);
            cTarget.setRetries(2);

            PDUv1 pdu = new PDUv1();
            pdu.setType(PDU.V1TRAP);
            pdu.setEnterprise(new OID(Oid));
            pdu.setGenericTrap(PDUv1.ENTERPRISE_SPECIFIC);
            pdu.setSpecificTrap(1);
            pdu.setAgentAddress(new IpAddress(ipAddress));
            
            /* see http://pic.dhe.ibm.com/infocenter/aix/v6r1/index.jsp?\
             *     topic=%2Fcom.ibm.aix.commadmn%2Fdoc%2Fcommadmndita%2F\
             *     snmpv1_daemon_trapprcess.htm
             * rfc1157 v1 trap pdu header format: followed by var-binding
             *  enterprise agent-address generic-trap specific-trap time-stamp 
             *    obj-id      integer       integer      integer     TimeTicks
             * the obj-id is the id of agent vendor, same as the value of 
             * the sysObjectID variable
             */
            pdu.setTimestamp(0x1234);
            pdu.add(new VariableBinding(SnmpConstants.snmpTrapOID, new OID(
                    Oid)));

            // Send the PDU
            Snmp snmp = new Snmp(transport);
            System.out.println("Sending V1 Trap... Check Wheather NMS is Listening or not? ");
            snmp.send(pdu, cTarget);
            snmp.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
