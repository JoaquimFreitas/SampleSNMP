/*_############################################################################
  _## 
  _##  SNMP4J-Agent 2 - SnmpFrameworkMIB.java  
  _## 
  _##  Copyright (C) 2005-2012  Frank Fock (SNMP4J.org)
  _##  
  _##  Licensed under the Apache License, Version 2.0 (the "License");
  _##  you may not use this file except in compliance with the License.
  _##  You may obtain a copy of the License at
  _##  
  _##      http://www.apache.org/licenses/LICENSE-2.0
  _##  
  _##  Unless required by applicable law or agreed to in writing, software
  _##  distributed under the License is distributed on an "AS IS" BASIS,
  _##  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  _##  See the License for the specific language governing permissions and
  _##  limitations under the License.
  _##  
  _##########################################################################*/


package org.snmp4j.agent.mo.snmp;

import org.snmp4j.agent.MOGroup;
import org.snmp4j.agent.MOServer;
import org.snmp4j.smi.OctetString;
import org.snmp4j.agent.DuplicateRegistrationException;
import org.snmp4j.agent.mo.MOScalar;
import org.snmp4j.agent.mo.MOAccessImpl;
import org.snmp4j.smi.OID;
import org.snmp4j.smi.Variable;
import org.snmp4j.smi.Integer32;
import java.util.Iterator;
import org.snmp4j.TransportMapping;
import java.util.Collection;
import org.snmp4j.security.USM;

public class SnmpFrameworkMIB implements MOGroup {

  private USM usm;
  private Collection<TransportMapping> transportMappings;

  private MOScalar snmpEngineID;
  private MOScalar snmpEngineBoots;
  private MOScalar snmpEngineTime;
  private MOScalar snmpEngineMaxMessageSize;

  public SnmpFrameworkMIB(USM usm, Collection<TransportMapping> transportMappings) {
    this.usm = usm;
    this.transportMappings = transportMappings;
    createMOs();
  }

  private void createMOs() {
    snmpEngineID = new MOScalar(new OID("1.3.6.1.6.3.10.2.1.1.0"),
                                MOAccessImpl.ACCESS_READ_ONLY,
                                null) {
      public Variable getValue() {
        return new OctetString(getUSM().getLocalEngineID());
      }
    };
    snmpEngineBoots = new MOScalar(new OID("1.3.6.1.6.3.10.2.1.2.0"),
                                   MOAccessImpl.ACCESS_READ_ONLY,
                                   null) {
      public Variable getValue() {
        return new Integer32(getUSM().getEngineBoots());
      }
    };
    snmpEngineTime = new MOScalar(new OID("1.3.6.1.6.3.10.2.1.3.0"),
                                  MOAccessImpl.ACCESS_READ_ONLY,
                                  null) {
      public Variable getValue() {
        return new Integer32(getUSM().getEngineTime());
      }
    };
    Integer32 maxMsgSize = new Integer32(getMaxMessageSize());
    snmpEngineMaxMessageSize = new MOScalar(new OID("1.3.6.1.6.3.10.2.1.4.0"),
                                            MOAccessImpl.ACCESS_READ_ONLY,
                                            maxMsgSize);
  }

  private int getMaxMessageSize() {
    int totalMaxMessageSize = 2147483647;
    for (Iterator<TransportMapping> it = transportMappings.iterator();
         it.hasNext();) {
      int maxMsgSize = (it.next()).getMaxInboundMessageSize();
      totalMaxMessageSize = Math.min(totalMaxMessageSize, maxMsgSize);
    }
    return totalMaxMessageSize;
  }

  public void registerMOs(MOServer server, OctetString context) throws
      DuplicateRegistrationException {
    if (usm != null) {
      server.register(snmpEngineID, context);
      server.register(snmpEngineBoots, context);
      server.register(snmpEngineTime, context);
    }
    server.register(snmpEngineMaxMessageSize, context);
  }

  public void unregisterMOs(MOServer server, OctetString context) {
    server.unregister(snmpEngineID, context);
    server.unregister(snmpEngineBoots, context);
    server.unregister(snmpEngineTime, context);
    server.unregister(snmpEngineMaxMessageSize, context);
  }

  public MOScalar getSnmpEngineBoots() {
    return snmpEngineBoots;
  }

  public MOScalar getSnmpEngineID() {
    return snmpEngineID;
  }

  public MOScalar getSnmpEngineMaxMessageSize() {
    return snmpEngineMaxMessageSize;
  }

  public MOScalar getSnmpEngineTime() {
    return snmpEngineTime;
  }

  public USM getUSM() {
    return usm;
  }

}
