java -jar /c/repos/hamlet/engine/bin/freemarker-wrapper-1.12.2.jar -i test.ftl -d /c/repos/hamlet/engine/client -o cmdb.json -d /c/repos/hamlet/engine/engine -d /c/repos/hamlet/engine-plugin-cmdb -g "/c/gs-immi/cot"; jq '.' <cmdb.json >cmdb-formatted.json
$GENERATION_DIR/createTemplate.sh -e cmdbmigration -p cmdb -o cmdbmigration -y "cmdbs=abtcgs,dryrun=yes,upgrade=v2.0.0"
$GENERATION_DIR/createTemplate.sh -e cmdbinfo -p cmdb -o cmdbinfo -y "actions=lists|cmdbs,cmdbs=abtcgs"

ACCOUNT=dibpnp22 ENVIRONMENT='production|prod' $GENERATION_DIR/createTemplate.sh -i mock -e cmdbinfo -p cmdb -o cmdbinfo -y "actions=inputs|context|cmdbs|content|FlattenedFilenamesOnly|qualified"

java -jar /home/ml019/hamlet/repos/engine/bin/freemarker-wrapper-1.13.0.jar -i test/test3.ftl -d . -d "/home/ml019/hamlet/repos/engine/engine" -o cmdb.json -g "/home/ml019/hamlet/gs-telstra/cot"; jq '.' <cmdb.json >cmdb-formatted.json
