#-------------------------------------------------------------------------------------------------------------
# Licensed under the MIT License.
#-------------------------------------------------------------------------------------------------------------

# centos image as a base
FROM centos:centos7

# Avoid warnings by switching to noninteractive
#ENV DEBIAN_FRONTEND=noninteractive


# This Dockerfile adds a non-root 'vscode' user with sudo access. However, for Linux,
# this user's GID/UID must match your local user UID/GID to avoid permission issues
# with bind mounts. Update USER_UID / USER_GID if yours is not 1000. See
# https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Proxy設定
ARG PROXY=''
ARG no_proxy='127.0.0.1,localhost,192.168.99.100,192.168.99.101,192.168.99.102,192.168.99.103,192.168.99.104,192.168.99.105,172.17.0.1'


# 自己証明が必要な場合はここで組み込む
ADD /etc/ssl/certs/      /etc/ssl/certs/

# Configure yum and install packages
RUN set -x \
    && if [ -n "$PROXY" ]; then echo -e "\n\
        ca_directory = /etc/ssl/certs/ \n\
        http_proxy = $PROXY \n\
        https_proxy = $PROXY \n\
    " >> /etc/wgetrc; fi\
    && yum -y install initscripts MAKEDEV \
    && yum check \
    && yum -y update \
    && mkdir $HOME/workspace \
# Install openssh
    && yum -y install openssh-server passwd \
# Install common tools
    && yum -y install rpmdevtools yum-utils net-tools zip unzip \
    #
# Install git
    && yum -y install https://centos7.iuscommunity.org/ius-release.rpm \
    && sed -ri 's/^#enabled=1/enabled=0/' /etc/yum.repos.d/ius.repo \
    && yum -y install git2u --enablerepo=ius \
    && git --version \
    #
# Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && yum install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    #
# make pgloader 
    && yum -y install make \
    && git clone https://github.com/dimitri/pgloader.git $HOME/workspace/pgloader \
    && chmod +x $HOME/workspace/pgloader/bootstrap-centos7.sh \
    && $HOME/workspace/pgloader/bootstrap-centos7.sh \
    && make $HOME/workspace/pgloader \
    #
# 空パスワードの場合は以下をコメントアウト
    && sed -ri 's/^#PermitEmptyPasswords no/PermitEmptyPasswords yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
#    && sed -ri 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config \
    && mkdir /var/run/sshd \
# 空パスワードの場合は以下をコメントアウト
    && passwd -d root \
# 任意のパスワードの場合は以下をコメントアウト & パスワードを書き換える
#    && echo "root:root" | chpasswd \
#
    && ssh-keygen -A \
#    && ssh-keygen -t rsa -N "" -f /etc/ssh/ssh_host_rsa_key \
#
# Clean up
    && rm -rf /var/cache/yum/* \
    && yum clean all
# Switch back to dialog for any ad-hoc use of apt-get
# ENV DEBIAN_FRONTEND=

EXPOSE 22
ENTRYPOINT [ "/usr/sbin/sshd", "-D" ]
