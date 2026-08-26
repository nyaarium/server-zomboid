FROM ubuntu:noble


# Adjust the game version here
ENV STEAM_APP_ID="380870"
ENV STEAM_BRANCH="public"
ENV GAME_BUILD="24775771"


RUN apt update -qq && apt install -qq -y locales tzdata ca-certificates && apt clean -y && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime \
    && echo "America/Los_Angeles" > /etc/timezone
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

ENV HOME=/root

RUN apt update && apt install -y \
	software-properties-common \
	&& apt autoremove --purge -y && apt clean

RUN apt update && apt install -y \
	ca-certificates \
	curl \
	screen \
	wget \
	&& apt autoremove --purge -y && apt clean


############################
# App dependencies

# lib32gcc-s1 is for 32-bit steamcmd. The game ships its own JRE at /app/jre64.
RUN apt update && apt install -y \
	lib32gcc-s1 \
	&& apt autoremove --purge -y && apt clean

RUN mkdir -p /root/steamcmd \
	&& cd /root/steamcmd \
	&& wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
	&& tar xvzf steamcmd_linux.tar.gz \
	&& rm steamcmd_linux.tar.gz


############################
# Game server

COPY docker/install.sh /root/install.sh
RUN chmod +x /root/install.sh \
	&& /root/install.sh \
	&& rm /root/install.sh


############################
# Server start script

COPY docker/docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

WORKDIR /app
CMD ["sleep", "infinity"]
