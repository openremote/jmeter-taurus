# A Custom docker image that just includes jmeter - the standard taurus image is bloated with all executors - this also
# adds plugins used so custom plugins can be easily included
FROM eclipse-temurin:21-jre-alpine

ARG JMETER_VERSION=5.6.3
ARG JMETER_PLUGIN_MANAGER_VERSION=1.10
# THIS MUST BE THE VERSION THAT THE PLUGIN MANAGER EXPECTS!
ARG CMD_RUNNER_VERSION=2.3

# Install python, pipx, bzt
ENV PYTHONUNBUFFERED=1
RUN apk add --update --no-cache python3 pipx \
    && ln -sf python3 /usr/bin/python \
    && apk add --no-cache --virtual .build-deps py3-setuptools py3-wheel cython gcc musl-dev build-base linux-headers python3-dev libxml2-dev libxslt-dev zlib-dev net-tools \
    && pipx install bzt \
    && apk del .build-deps

ENV JMETER_VERSION=${JMETER_VERSION}
ENV JMETER_PLUGIN_MANAGER_VERSION=${JMETER_PLUGIN_MANAGER_VERSION}
ENV PATH="${PATH}:/root/.local/bin"

# Download JMeter so we can load our custom plugins (taurus can only download plugins from the JMeter Plugins Manager)
# Download Plugins manager (for standard plugins resolution)
RUN cd /tmp \
    && wget -c https://dlcdn.apache.org/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz -O - | tar -xz \
    && mkdir -p /root/.bzt/jmeter-taurus \
    && mv apache-jmeter-${JMETER_VERSION} /root/.bzt/jmeter-taurus/${JMETER_VERSION} \
    && wget -P /root/.bzt/jmeter-taurus/${JMETER_VERSION}/lib/ext/ -c https://repo1.maven.org/maven2/kg/apc/jmeter-plugins-manager/${JMETER_PLUGIN_MANAGER_VERSION}/jmeter-plugins-manager-${JMETER_PLUGIN_MANAGER_VERSION}.jar \
    && wget -P /root/.bzt/jmeter-taurus/${JMETER_VERSION}/lib -c https://repo1.maven.org/maven2/kg/apc/cmdrunner/${CMD_RUNNER_VERSION}/cmdrunner-${CMD_RUNNER_VERSION}.jar \
    && java -cp /root/.bzt/jmeter-taurus/${JMETER_VERSION}/lib/ext/jmeter-plugins-manager-${JMETER_PLUGIN_MANAGER_VERSION}.jar org.jmeterplugins.repository.PluginManagerCMDInstaller \
    && wget -P /root/.bzt/jmeter-taurus/${JMETER_VERSION}/lib/ext/ -c https://github.com/richturner/mqtt-jmeter/releases/download/2.0.5-RT/plugin-xmeter-2.0.5-RT-jar-with-dependencies.jar \
    && mkdir /bzt-configs /tmp/artifacts \
    && mkdir -p /etc/bzt.d \
    && echo "settings:" >> /root/.bzt-rc \
    && echo "  artifacts-dir: /tmp/artifacts" >> /root/.bzt-rc

WORKDIR /bzt-configs/
ENTRYPOINT ["sh", "-c", "bzt -o settings.env.JMETER_VERSION=${JMETER_VERSION} -l /tmp/artifacts/bzt.log \"$@\"", "ignored"]
