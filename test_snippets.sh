java -jar /c/repos/hamlet/engine/bin/freemarker-wrapper-1.12.1-rc10.jar -i test.ftl -d /c/repos/hamlet/engine/client -o cmdb.json -d /c/repos/hamlet/engine/engine -d /c/repos/hamlet/engine-plugin-cmdb -g "/c/gs-immi/cot"; jq '.' <cmdb.json >cmdb-formatted.json
$GENERATION_DIR/createTemplate.sh -i mock -e cmdbmigration -p cmdb -o cmdbmigration -y "cmdbs=abtcgs,dryrun=yes,upgrade=v2.0.0"
$GENERATION_DIR/createTemplate.sh -i mock -e cmdbinfo -p cmdb -o cmdbinfo -y "actions=lists|cmdbs,cmdbs=abtcgs"

ACCOUNT=dibpnp22 ENVIRONMENT='production|prod' $GENERATION_DIR/createTemplate.sh -i mock -e cmdbinfo -p cmdb -o cmdbinfo -y "actions=inputs|context|cmdbs|content|FlattenedFilenamesOnly|qualified"