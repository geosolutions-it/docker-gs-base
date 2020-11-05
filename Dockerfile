ARG BASE_IMAGE_NAME=tomcat
ARG BASE_IMAGE_TAG=latest
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}
LABEL maintainer="alessandro.parma@geo-solutions.it"
ARG BASE_IMAGE_TAG

RUN  export DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl
#RUN  ln -s /bin/true /sbin/initctl

# Install updates
RUN apt-get -y update

# Install full JDK 8
RUN apt-get -y install openjdk-8-jdk

#------------- Copy resources from local file system --------------------------
ONBUILD ENV RESOURCES_DIR="/resources"
ONBUILD ADD resources $RESOURCES_DIR

#------------- GeoServer Specific Stuff ---------------------------------------
ONBUILD ENV CATALINA_BASE $CATALINA_HOME

# Name of application to deploy into Tomcat's webapps dir
ONBUILD ARG GEOSERVER_APP_NAME="geoserver"
ONBUILD ENV GEOSERVER_APP_NAME "${GEOSERVER_APP_NAME}"

# Externalize various files and dirs
ONBUILD ARG GEOSERVER_HOME="/var/geoserver"
ONBUILD ENV GEOSERVER_HOME="${GEOSERVER_HOME}"

ONBUILD ARG GEOSERVER_DATA_DIR="${GEOSERVER_HOME}/datadir"
ONBUILD ENV GEOSERVER_DATA_DIR="${GEOSERVER_DATA_DIR}"

ONBUILD ARG GEOSERVER_AUDIT_PATH="${GEOSERVER_HOME}/audits"
ONBUILD ENV GEOSERVER_AUDIT_PATH="${GEOSERVER_AUDIT_PATH}"

ONBUILD ARG GEOSERVER_LOG_LOCATION="${GEOSERVER_HOME}/logs"
ONBUILD ENV GEOSERVER_LOG_LOCATION="${GEOSERVER_LOG_LOCATION}"

ONBUILD ARG GEOWEBCACHE_CACHE_DIR="${GEOSERVER_HOME}/gwc_cache_dir"
ONBUILD ENV GEOWEBCACHE_CACHE_DIR="${GEOWEBCACHE_CACHE_DIR}"

ONBUILD ARG GEOWEBCACHE_CONFIG_DIR="${GEOSERVER_HOME}/gwc"
ONBUILD ENV GEOWEBCACHE_CONFIG_DIR="${GEOWEBCACHE_CACHE_DIR}"

ONBUILD ARG OOM_DUMP_DIR="${GEOSERVER_HOME}/memory_dumps"
ONBUILD ENV OOM_DUMP_DIR="${OOM_DUMP_DIR}"

# Print environment
ONBUILD RUN \
    echo "" \
    "Resources Dir:  ${RESOURCES_DIR}\n"  \
    "GeoServer Home: ${GEOSERVER_HOME}\n" \
    "DataDir Path:   ${GEOSERVER_DATA_DIR}     \n" \
    "Audit Path:     ${GEOSERVER_AUDIT_PATH}   \n" \
    "Log Location:   ${GEOSERVER_LOG_LOCATION} \n" \
    "GWC CacheDir:   ${GEOWEBCACHE_CACHE_DIR}  \n" \
    "GWC ConfDir:    ${GEOWEBCACHE_CONFIG_DIR} \n" \
    "MemDumps Dir:   ${OOM_DUMP_DIR} \n"  \
    >> docker_build.log

# Create GeoServer directories
ONBUILD RUN \
    GEOSERVER_LOG_DIR=$(dirname ${GEOSERVER_LOG_LOCATION}); \
    mkdir -p \
    "${GEOSERVER_DATA_DIR}"      \
    "${GEOSERVER_AUDIT_PATH}"    \
    "${GEOSERVER_LOG_DIR}"  \
    "${GEOWEBCACHE_CACHE_DIR}"   \
    "${GEOWEBCACHE_CONFIG_DIR}"  \
    "${OOM_DUMP_DIR}"  

# Set default JAVA_OPTS (override as needed at run time)
ONBUILD ARG JAVA_OPTS="-Xms1024m -Xmx1024m -XX:+UseParallelGC -XX:+UseParallelOldGC \
    -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR}                        \
    -DGEOWEBCACHE_CACHE_DIR=${GEOWEBCACHE_CACHE_DIR}                  \
    -DGEOSERVER_LOG_LOCATION=${GEOSERVER_LOG_LOCATION}/geoserver.log  \
    -DGEOWEBCACHE_CONFIG_DIR=${GEOWEBCACHE_CONFIG_DIR}                \
    -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${OOM_DUMP_DIR}"

ONBUILD ENV JAVA_OPTS "$JAVA_OPTS"

# Optionally remove Tomcat manager, docs, and examples
ONBUILD ARG TOMCAT_EXTRAS=false
ONBUILD ENV TOMCAT_EXTRAS "$TOMCAT_EXTRAS"
ONBUILD RUN \
    if [ "$TOMCAT_EXTRAS" = false ]; then \
        rm -rfv "${CATALINA_HOME}/webapps/*" \
    ; fi

# Move GeoServer war into Tomcat webapps dir
ONBUILD ARG INCLUDE_GS_WAR="false"
ONBUILD ENV INCLUDE_GS_WAR "${INCLUDE_GS_WAR}"

# Install any plugin zip files found in ${RESOURCES_DIR}/geoserver-plugins
ONBUILD ARG INCLUDE_PLUGINS="false"
ONBUILD ENV INCLUDE_PLUGINS "${INCLUDE_PLUGINS}"

ONBUILD ARG PLUGINS_DIR="${RESOURCES_DIR}/geoserver-plugins"
ONBUILD ENV PLUGINS_DIR "${PLUGINS_DIR}"

ONBUILD ARG PLUGINS_TMPDIR="${RESOURCES_DIR}/geoserver-plugins-unpacked"
ONBUILD ENV PLUGINS_TMPDIR "${PLUGINS_TMPDIR}"

ONBUILD RUN if [ "$INCLUDE_GS_WAR" = true ]; then \
              mv "${RESOURCES_DIR}/geoserver/geoserver.war" \
              "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}.war"; \
            fi;

ONBUILD RUN \
    if [ "${INCLUDE_PLUGINS}" = "true" ]; then \
      mkdir -p "$PLUGINS_TMPDIR"; \
      unzip "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}.war" \
      -d "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}"; \
      rm "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}.war"; \
      plugins=$( ls -1 "${PLUGINS_DIR}" | grep "zip$" ) \
      && plugins_num=$( echo "$plugins" | wc -l );  \
      echo "Found: $plugins_num plugins \n Plugins list:\n\t $plugins"; \
      for plugin in $plugins; do \
        if [ "$INCLUDE_GS_WAR" = "true" ]; then \
            echo "\t Plugin: $plugin" \
            && unzip "${PLUGINS_DIR}/$plugin" -d "$PLUGINS_TMPDIR"; \
            jars=$( ls -1 "${PLUGINS_TMPDIR}" | grep "jar$" ); \
            for jar in $jars; do \
              if [ -f "${PLUGINS_DIR}/$plugin" ]; then \
                mv -v "${PLUGINS_TMPDIR}/$jar" "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}/WEB-INF/lib/"; \
              fi; \
            done; \
        fi; \
      done; \
    fi;

# ONBUILD RUN rm -rf "${PLUGINS_TMPDIR}";


# Include local data dir in image
ONBUILD ARG INCLUDE_DATA_DIR=false
ONBUILD ENV INCLUDE_DATA_DIR $INCLUDE_DATA_DIR
ONBUILD RUN if [ "$INCLUDE_DATA_DIR" = true ]; then \
    cp -a /resources/geoserver-datadir/* "${GEOSERVER_DATA_DIR}" \
    && rm -rf /resources/geoserver-datadir \
    ; fi

# Add Marlin Renderer to WEB-INF/lib directory
ONBUILD ARG ADD_MARLIN_RENDERER=false
ONBUILD ENV ADD_MARLIN_RENDERER $ADD_MARLIN_RENDERER
ONBUILD RUN if [ "$ADD_MARLIN_RENDERER" = true ]; then \
    find "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}/WEB-INF/lib" -name 'marlin*jar' -delete; \
    cp -a /resources/marlin/* "${CATALINA_BASE}/webapps/${GEOSERVER_APP_NAME}/WEB-INF/lib/" \
    && rm -rf /resources/marlin/* \
    ; fi

# Add extra fonts to JVM
ONBUILD ARG ADD_EXTRA_FONTS=false
ONBUILD ENV ADD_EXTRA_FONTS $ADD_EXTRA_FONTS
ONBUILD RUN if [ "$ADD_EXTRA_FONTS" = true ]; then \
    java_path=$(update-alternatives --list java); \
    java_fonts_dir=$(dirname $java_path)/../lib/fonts; \
    mkdir -p "$java_fonts_dir"; \
    tar -xvf /resources/fonts/* -C "$java_fonts_dir" \
    && rm -rf /resources/fonts/* \
    ; fi

#------------- Cleanup --------------------------------------------------------

# Delete resources after installation
#ONBUILD RUN    rm -rf "/tmp/resources" \
#            && rm -rf "/var/lib/apt/lists/*"

WORKDIR $CATALINA_HOME
ONBUILD ADD catalina-wrapper.sh "${CATALINA_HOME}/bin"

ENV TERM xterm

EXPOSE 8080

CMD ["catalina-wrapper.sh"]
