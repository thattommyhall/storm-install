DOMAIN = 'something.com'
#You will need to edit zoo.cfg and storm.yaml also

role :zookeepers, *(1..3).map{|n| "zookeeper#{n}.#{DOMAIN}"}
role :nimbus, "storm-nimbus.#{DOMAIN}"
role :workers, *(1..5).map{|n| "storm-worker#{n}.#{DOMAIN}"}

namespace :zookeeper do
  task :install, :roles => :zookeepers do
    sudo "apt-get update"
    sudo "apt-get upgrade -y"
    sudo "apt-get install -y curl"
    sudo "curl -s http://archive.cloudera.com/debian/archive.key | sudo apt-key add -"
    upload File.join(File.dirname(__FILE__), 'java-accept-lic'), '/tmp/java-accept-lic', :mode => '644'
    sudo "/usr/bin/debconf-set-selections /tmp/java-accept-lic"
    upload File.join(File.dirname(__FILE__), 'cloudera.list'), '/tmp/cloudera.list', :mode => '644'
    sudo "mv /tmp/cloudera.list /etc/apt/sources.list.d/cloudera.list"
    upload File.join(File.dirname(__FILE__), 'partner.list'), '/tmp/partner.list', :mode => '644'
    sudo "mv /tmp/partner.list /etc/apt/sources.list.d/partner.list"
    upload File.join(File.dirname(__FILE__), 'zoo.cfg'), '/tmp/zoo.cfg', :mode => '644'
    sudo "mv /tmp/zoo.cfg /etc/zookeeper/zoo.cfg"
    sudo "apt-get update"
    sudo "apt-get install -y hadoop-zookeeper-server"
    sudo "apt-get -y autoremove"
    
    #hack, assumes machines are named zookeeperN
    run "echo `cat /etc/hostname | cut --complement -c 1-9` > /tmp/myid"
    sudo "cp /tmp/myid /var/zookeeper/myid"
  end
  
  task :restart, :roles => :zookeepers do
    sudo "/etc/init.d/hadoop-zookeeper-server restart"
  end

  task :stop, :roles => :zookeepers do
    sudo "/etc/init.d/hadoop-zookeeper-server stop"
  end

  task :start, :roles => :zookeepers do
    sudo "/etc/init.d/hadoop-zookeeper-server start"
  end
  after 'zookeeper:install', 'zookeeper:restart'
end

namespace :install do 
  task :all, :roles => [:nimbus,:workers] do
    sudo "apt-get update"
    sudo "apt-get upgrade -y"
    sudo "apt-get install -y --force-yes python-software-properties git-core curl"
    upload File.join(File.dirname(__FILE__), 'java-accept-lic'), '/tmp/java-accept-lic', :mode => '644'
    sudo "/usr/bin/debconf-set-selections /tmp/java-accept-lic"
    upload File.join(File.dirname(__FILE__), 'partner.list'), '/tmp/partner.list', :mode => '644'
    sudo "mv /tmp/partner.list /etc/apt/sources.list.d/partner.list"
    sudo "add-apt-repository ppa:chris-lea/libpgm"
    sudo "add-apt-repository ppa:chris-lea/zeromq"
    sudo "apt-get update"
    sudo "apt-get install -y --force-yes sun-java6-jdk uuid-dev build-essential pkg-config libtool autoconf automake libzmq-dev libpgm-dev unzip
"
    run "if [ ! -f /usr/local/lib/libjzmq.so.0.0.0 ]; then " +
      "sudo rm -rf ./jzmq/ && " +
      "git clone https://github.com/nathanmarz/jzmq.git && " + 
      "cd jzmq && " +
      "JAVA_HOME=/usr/lib/jvm/java-6-sun ./autogen.sh && " +
      "JAVA_HOME=/usr/lib/jvm/java-6-sun ./configure && " +
      "JAVA_HOME=/usr/lib/jvm/java-6-sun make && " +
      "JAVA_HOME=/usr/lib/jvm/java-6-sun sudo make install; fi"
    run "cd /usr/local; if [ ! -f /usr/local/storm/bin/storm ]; then sudo wget -nc https://github.com/downloads/nathanmarz/storm/storm-0.5.3.zip && sudo unzip -o storm-0.5.3.zip; fi"
    sudo "ln -sf /usr/local/storm-0.5.3 /usr/local/storm"
    upload File.join(File.dirname(__FILE__), 'storm.yaml'), '/tmp/storm.yaml'
    sudo "mv /tmp/storm.yaml /usr/local/storm/conf/storm.yaml"
  end

  task :upstart_workers, :roles => :workers do
    upload File.join(File.dirname(__FILE__), 'upstart', 'storm-supervisor.conf'), '/tmp/storm-supervisor.conf', :mode => '644'
    sudo "mv /tmp/storm-supervisor.conf /etc/init"
  end
  
  task :upstart_nimbus, :roles => :nimbus do
    upload File.join(File.dirname(__FILE__), 'upstart', 'storm-ui.conf'), '/tmp/storm-ui.conf', :mode => '644'
    sudo "mv /tmp/storm-ui.conf /etc/init"

    upload File.join(File.dirname(__FILE__), 'upstart', 'storm-nimbus.conf'), '/tmp/storm-nimbus.conf', :mode => '644'
    sudo "mv /tmp/storm-nimbus.conf /etc/init"
  end

  after 'install:all', 'install:upstart_nimbus', 'install:upstart_workers', 'nimbus:start', 'supervisors:start', 'ui:start'

end

namespace :supervisors do
  task :start, :roles => :workers do
    sudo "start storm-supervisor"
  end
  task :restart, :roles => :workers do
    sudo "restart storm-supervisor"
  end
  task :stop, :roles => :workers do
    sudo "stop storm-supervisor"
  end
end

namespace :nimbus do
  task :start, :roles => :nimbus do
    sudo "start storm-nimbus"
  end
  
  task :restart, :roles => :nimbus do
    sudo "restart storm-nimbus"
  end
  
  task :stop, :roles => :nimbus do
    sudo "stop storm-nimbus"
  end
end

namespace :ui do
  task :start, :roles => :nimbus do
    sudo "start storm-ui"
  end
  task :restart, :roles => :nimbus do
      sudo "restart storm-ui"
  end
  task :stop, :roles => :nimbus do
    sudo "stop storm-ui"
  end
end