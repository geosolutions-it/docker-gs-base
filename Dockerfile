ARG BASE_IMAGE_TAG=latest
FROM tomcat:${BASE_IMAGE_TAG}
MAINTAINER Alessandro Parma<alessandro.parma@geo-solutions.it>
ARG BASE_IMAGE_TAG

RUN  export DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl
#RUN  ln -s /bin/true /sbin/initctl

# Install updates
RUN apt-get -y update

#------------- Copy resources from local file system --------------------------
ONBUILD ENV RESOURCES_DIR="/tmp/resources"
ONBUILD ADD resources $RESOURCES_DIR

#------------- GeoServer Specific Stuff ---------------------------------------
ONBUILD ENV CATALINA_BASE $CATALINA_HOME

# Set env vars for GeoServer 
ONBUILD ARG GEOSERVER_APP_NAME="geoserver.war"
ONBUILD ARG GEOSERVER_HOME="/var/geoserver"
ONBUILD ARG GEOSERVER_DATA_DIR="${GEOSERVER_HOME}/datadir"
ONBUILD ARG GEOSERVER_AUDIT_PATH="${GEOSERVER_HOME}/audits"
ONBUILD ARG GEOSERVER_LOG_LOCATION="${GEOSERVER_HOME}/logs"
ONBUILD ARG GEOWEBCACHE_CACHE_DIR="${GEOSERVER_HOME}/gwc_cache_dir"

# Print environment
ONBUILD RUN \
    echo "" \
    "Resources Dir:  ${RESOURCES_DIR}\n"  \
    "GeoServer Home: ${GEOSERVER_HOME}\n" \
    "DataDir Path:   ${GEOSERVER_DATA_DIR}    \n" \
    "Audit Path:     ${GEOSERVER_HOME}/audits \n" \
    "Log Location:   ${GEOSERVER_LOG_LOCATION}\n" \
    "GWC CacheDir:   ${GEOWEBCACHE_CACHE_DIR} \n" \
    >> docker_build.log

# Create GeoServer directories
ONBUILD RUN mkdir -p \
    "${GEOSERVER_DATA_DIR}"     \
    "${GEOSERVER_AUDIT_PATH}"   \
    "${GEOSERVER_LOG_LOCATION}" \
    "${GEOWEBCACHE_CACHE_DIR}"  

# Set default JAVA_OPTS (override as needed at run time)
ONBUILD ENV JAVA_OPTS="-Xms1024m -Xmx1024m -XX:+UseParallelGC -XX:+UseParallelOldGC \
    -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR} \
    -DGEOWEBCACHE_CACHE_DIR=${GEOWEBCACHE_CACHE_DIR} \
    -DGEOSERVER_LOG_LOCATION=${GEOSERVER_LOG_LOCATION}/geoserver.log"

# Optionally remove Tomcat manager, docs, and examples
ONBUILD ARG TOMCAT_EXTRAS=false
ONBUILD ENV TOMCAT_EXTRAS "$TOMCAT_EXTRAS"
ONBUILD RUN \
    if [ "$TOMCAT_EXTRAS" = false ]; then \
        rm -rf "${CATALINA_HOME}/webapps/*" \
    ; fi

# Move GeoServer war into Tomcat webapps dir
ONBUILD RUN mv "${RESOURCES_DIR}/geoserver/geoserver.war" \
            "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}.war" \
            && unzip "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}.war" \
            -d "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}"

# Install any plugin zip files found in ${RESOURCES_DIR}/geoserver-plugins
ONBUILD ENV PLUGINS_DIR "${RESOURCES_DIR}/geoserver-plugins"
ONBUILD ENV PLUGINS_TMPDIR "${RESOURCES_DIR}/geoserver-plugins-unpacked"
ONBUILD RUN \
    plugins=$( ls "${PLUGINS_DIR}" | grep "zip$" ) \
    && plugins_num=$( echo "$plugins" | wc -l );  \
    echo "Found: $plugins_num plugins \n Plugins list:\n\t $plugins" >> docker_build.log; \
    if [ "$plugins_num" -ne 0 ]; then \
      mkdir -p "$PLUGINS_TMPDIR"; \
      for plugin in "$plugins"; do \
        echo "\t Plugin: $plugin" >> docker_build.log \
        && echo unzip "${PLUGINS_DIR}/$plugin" -d "$PLUGINS_TMPDIR" \
        && unzip "${PLUGINS_DIR}/$plugin" -d "$PLUGINS_TMPDIR"; \
      done; \
    fi

ONBUILD RUN \
      jars=$( ls "${PLUGINS_TMPDIR}" | grep "jar$" ); \
      for jar in "$jars"; do \
        mv -v "${PLUGINS_TMPDIR}/$jar" "${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/"; \
      done;
# ONBUILD RUN rm -rf "${PLUGINS_TMPDIR}";


# Include local data dir in image
ONBUILD ARG INCLUDE_DATA_DIR=true
ONBUILD ENV INCLUDE_DATA_DIR $INCLUDE_DATA_DIR
ONBUILD RUN if [ "$INCLUDE_DATA_DIR" = true ]; then \
    cp -a /tmp/resources/geoserver-datadir/* "${GEOSERVER_DATA_DIR}" \
    && rm -rf /tmp/resources/geoserver-datadir \
    ; fi

#------------- Cleanup --------------------------------------------------------

# Delete resources after installation
#ONBUILD RUN    rm -rf "/tmp/resources" \
#            && rm -rf "/var/lib/apt/lists/*"

WORKDIR $CATALINA_HOME

ENV TERM xterm

EXPOSE 8080
