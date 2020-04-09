#!/usr/bin/env bash

set -o errexit

LIFERAY_HOME=/opt/liferay

mkdir dbupgradeclient
curl -o $LIFERAY_HOME/dbupgradeclient.zip https://repository.liferay.com/nexus/content/repositories/liferay-public-releases/com/liferay/com.liferay.portal.tools.db.upgrade.client/3.0.1/com.liferay.portal.tools.db.upgrade.client-3.0.1.zip
unzip $LIFERAY_HOME/dbupgradeclient.zip -d dbupgradeclient
rm -f $LIFERAY_HOME/dbupgradeclient.zip

LIFERAY_UPGRADE_HOME=$LIFERAY_HOME/dbupgradeclient
chmod +x $LIFERAY_UPGRADE_HOME/*.sh
ls $LIFERAY_UPGRADE_HOME

printf "dir=../tomcat\nextra.lib.dirs=/bin\nglobal.lib.dir=/lib\nportal.dir=/webapps/ROOT\nserver.detector.server.id=tomcat" > $LIFERAY_UPGRADE_HOME/app-server.properties
printf "jdbc.default.driverClassName=com.mysql.cj.jdbc.Driver\njdbc.default.url=jdbc:mysql://database/lportal?characterEncoding=UTF-8&dontTrackOpenResources=true&holdResultsOpenOverStatementClose=true&serverTimezone=GMT&useFastDateParsing=false&useUnicode=true\njdbc.default.username=dxpcloud\njdbc.default.password=dxpcloud" > $LIFERAY_UPGRADE_HOME/portal-upgrade-database.properties
printf "liferay.home=../\nretry.jdbc.on.startup.max.retries=99" > $LIFERAY_UPGRADE_HOME/portal-upgrade-ext.properties

printf "indexReadOnly=true" $LIFERAY_HOME/osgi/configs/com.liferay.portal.search.configuration.IndexStatusManagerConfiguration.cfg

chmod +x $LIFERAY_UPGRADE_HOME/db_upgrade.sh

$LIFERAY_UPGRADE_HOME/db_upgrade.sh -j "-Dfile.encoding=UTF-8 -Duser.country=US -Duser.language=en -Duser.timezone=GMT -Xmx10g"

touch /lcp-container/script/local/upgrade_done