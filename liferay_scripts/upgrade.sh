#!/usr/bin/env bash

set -o errexit

LIFERAY_HOME=/opt/liferay

curl -o $LIFERAY_HOME/tools.zip http://files.liferay.int/private/ee/portal/7.2.10.1/liferay-dxp-tools-7.2.10.1-sp1-20191007154602574.zip
unzip $LIFERAY_HOME/tools.zip
rm -f $LIFERAY_HOME/tools.zip

LIFERAY_UPGRADE_HOME=$LIFERAY_HOME/liferay-portal-tools-7.2.10.1-sp1

printf "dir=../tomcat\nextra.lib.dirs=/bin\nglobal.lib.dir=/lib\nportal.dir=/webapps/ROOT\nserver.detector.server.id=tomcat" > $LIFERAY_UPGRADE_HOME/app-server.properties
printf "jdbc.default.driverClassName=com.mysql.cj.jdbc.Driver\njdbc.default.url=jdbc:mysql://database/lportal?characterEncoding=UTF-8&dontTrackOpenResources=true&holdResultsOpenOverStatementClose=true&serverTimezone=GMT&useFastDateParsing=false&useUnicode=true\njdbc.default.username=dxpcloud\njdbc.default.password=dxpcloud" > $LIFERAY_UPGRADE_HOME/portal-upgrade-database.properties
printf "liferay.home=../\nretry.jdbc.on.startup.max.retries=99" > $LIFERAY_UPGRADE_HOME/portal-upgrade-ext.properties

printf "indexReadOnly=true" $LIFERAY_HOME/osgi/configs/com.liferay.portal.search.configuration.IndexStatusManagerConfiguration.cfg

chmod +x $LIFERAY_UPGRADE_HOME/db_upgrade.sh

$LIFERAY_UPGRADE_HOME/db_upgrade.sh -j "-Dfile.encoding=UTF-8 -Duser.country=US -Duser.language=en -Duser.timezone=GMT -Xmx5g"

touch /lcp-container/script/local/upgrade_done