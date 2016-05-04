FROM sparklyballs/armhf-vanilla

# change to tag of build you want
ARG KODI_CHECKOUT="16.1-Jarvis"

# change home environment
ENV HOME="/config"
ARG _anthome="/usr/share/java/apache-ant"

# copy in patches required for building in alpine
COPY patches/ /patches/

# set build dependencies
ARG BUILD_LIST="alpine-sdk autoconf automake avahi-dev boost-dev build-base cmake \
curl-dev faac-dev ffmpeg ffmpeg-dev ffmpeg-libs findutils flac-dev gawk gettext-dev \
giflib-dev glew-dev gnutls-dev gperf jasper-dev jpeg-dev libass-dev libbluray-dev \
libbz2 libcap-dev libcdio-dev libjpeg-turbo-dev libmicrohttpd-dev libmpeg2-dev \
libnfs-dev libssh-dev libtool libvorbis-dev libxrandr-dev libxslt-dev lzo-dev \
mariadb-dev nasm openjpeg-dev openjdk7 pcre-dev py-imaging python-dev readline-dev \
samba-dev sqlite-dev swig taglib-dev tiff-dev tinyxml-dev util-linux-dev wget yajl-dev \
yasm zip"

# set runtime dependencies
ARG APKLIST="faac ffmpeg-libs flac freetype fribidi glew glu gnutls jasper jpeg \
libass libbluray libcdio++ libbz2 libmicrohttpd libogg libpcrecpp libpng libsmbclient \
libssh libuuid libvorbis libxml2 libxrandr libxslt lzo mariadb-libs mesa-gles nettle \
python sqlite taglib tiff tinyxml yajl"

# install build dependencies
RUN apk add --update $BUILD_LIST && \

# build apache ant
curl -o /tmp/ant.bz2 -L http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.7-bin.tar.bz2 && \
mkdir -p /tmp/ant-source && \
tar xvf /tmp/ant.bz2 -C /tmp/ant-source --strip-components=1 && \
cd /tmp/ant-source && \
install -dm755 "$_anthome"/bin && \
rm bin/*.bat bin/*.cmd && \
install -m755 bin/* "$_anthome"/bin || exit 1 && \
install -dm755 /usr/bin && \
ln -sf "$_anthome"/bin/ant /usr/bin/ant || exit 1 && \
cp -r etc / || exit 1 && \
install -dm755 "$_anthome"/lib && \
install -m644 lib/*.jar "$_anthome"/lib || exit 1 && \
ln -sf ../../junit.jar "$_anthome"/lib/junit.jar || exit 1 && \

# clone source code
git clone https://github.com/xbmc/xbmc.git -b "$KODI_CHECKOUT" --depth=1 /tmp/kodi_source && \

# compile libbluray
git clone http://git.videolan.org/git/libbluray.git /tmp/libbluray && \
cd /tmp/libbluray || exit && \
git checkout c188f00496b83615dc873e8ec52f61351309377f && \
./bootstrap && \
./configure --enable-bdjava --prefix=/usr && \
make && \
make install && \

# build kodi sourced dependencies
cd /tmp/kodi_source && \
make -C tools/depends/target/crossguid PREFIX=/usr && \
make -C tools/depends/target/libdcadec PREFIX=/usr && \

# apply patches
git apply /patches/headless.patch && \
git apply /patches/add-missing-includes.patch && \
git apply /patches/fix-fileemu.patch && \
# git apply /patches/fix-musl-x86.patch && \
git apply /patches/fix-musl.patch && \
git apply /patches/fortify-source-fix.patch && \
git apply /patches/remove-filewrap.patch && \
git apply /patches/set-default-stacksize.patch && \

# bootstrap and configure kodi
./bootstrap && \
./configure --disable-airplay --disable-airtunes --disable-alsa --disable-asap-codec \
--disable-avahi --disable-dbus --disable-debug --disable-dvdcss --disable-goom \
--disable-joystick --disable-libcap --disable-libcec --disable-libusb \
--disable-non-free --disable-openmax --disable-optical-drive --disable-projectm \
--disable-pulse --disable-rsxs --disable-rtmp --disable-spectrum --disable-udev \
--disable-vaapi --disable-vdpau --disable-vtbdecoder --disable-waveform --enable-libbluray \
--enable-nfs --enable-ssh --enable-upnp --with-ffmpeg=shared && \

# compile kodi
make && \
make install && \

# cleanup build dependencies
apk del --purge $BUILD_LIST && \
rm -rf /var/cache/apk/* /tmp/*

# install runtime dependencies
RUN apk add --update $APKLIST && \
rm -rf /var/cache/apk/*

# copy local files for runtime
COPY root/ /

# ports and volumes
VOLUME /config/.kodi
EXPOSE 8080 9777/udp


