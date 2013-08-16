
require 'rubygems'
require 'open4'          # so we can get pid, stdin, stdout, stderr from Topaz
require 'json'           # our response to AJAX requests
require 'socket'    
require 'gemstone_ruby'  # GemStone C Interface

gsHost = 'localhost'
gsPort = nil

Thread.abort_on_exception = true

Thread.new do
  string = ARGV.first
  string ||= "(ZnServer startOn: nil) serverSocket port"
  GemStone.login
  gsPort = GemStone.executeString string
  puts "started GemStone server on #{ gsHost }:#{ gsPort.to_s } using gemstone_ruby-#{ GemStone::VERSION }"
  GemStone.executeString "[true] whileTrue: [(Delay forSeconds: 60) wait]. nil"
end

trap("SIGINT") { 
  puts "\nLogging out of GemStone"
  GemStone.GciHardBreak
  sleep 0.1
  GemStone.GciLogout
  sleep 0.1
  GemStone.GciShutdown
  sleep 0.1
  exit!
}

port = ENV["PORT"]
port ||= 8080
listener = TCPServer.open port
listener.listen(20)
puts "zinc.rb listening on localhost:#{ port.to_s }"
loop {                           # Servers run forever
  Thread.start(listener.accept) do |client|
    server = TCPSocket.open(gsHost, gsPort)
    thread1 = Thread.new do
      loop {
        string = client.readpartial(4096) rescue nil
        if string.nil?
          thread2.terminate!
          server.close
          client.close
          thread1.terminate!
        end
        x = server.sendmsg(string)
        if (string.length != x)
          raise "attempted to send #{ string.length } but only sent #{ x }"
        end
      }
    end
    thread2 = Thread.new do
      loop {
        string = server.readpartial(4096) rescue nil
        if string.nil?
          thread1.terminate!
          client.close
          server.close
          thread2.terminate!
        end
        x = client.sendmsg(string)
        if (string.length != x)
          raise "attempted to send #{ string.length } but only sent #{ x }"
        end
      }
    end
  end
}
