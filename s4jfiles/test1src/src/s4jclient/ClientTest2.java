/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 * 
 * ClientTest1 -- refactored from TestSNMPAgent.
 */
package s4jclient;

import com.G2.SNMP.client.SNMPManager;
import java.io.IOException;
import org.snmp4j.smi.OID;

/**
 *
 * @author me
 */
public class ClientTest2 {

    static final OID sysDescr = new OID(".1.3.6.1.2.1.1.1.0");
   
    /**
     * @param args the command line arguments
     */
    public static void main(String[] args) throws IOException {
        // TODO code application logic here
        ClientTest2 client = new ClientTest2("udp:127.0.0.1/7161");
        client.init();
    }
    
    SNMPManager client = null;
    String address = null;

    /**
     * Constructor
     *
     * @param add
     */
    public ClientTest2(String add) {
        address = add;
    }

    private void init() throws IOException {
        // Setup the client to use our newly started agent
        client = new SNMPManager(address);
        client.start();
        // Get back Value which is set
        System.out.printf(" Use SNMP GETNEXT ... \n");
        //System.out.println(client.getAsString(sysDescr));
        System.out.println(client.getNextAsString(sysDescr));
    }
}
