[#ftl]

[#assign CMDB_PROVIDER = "cmdb"]

[#include "cmdb.ftl"]

[#-- Have the wrapper assess the CMDBs it finds configured --]
[@initialiseCMDB /]

[#-- Now analyse the structure of the CMDBS --]
[@analyseCMDBStructure /]

