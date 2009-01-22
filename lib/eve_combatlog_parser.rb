# vim:sw=2
#require 'rubygems'
#require 'activerecord'
require 'ruby-debug'


module Eve
  module Combatlog
    
  	class Parser
  	  attr_accessor :owner, :session_start, :lines
  	  
      def initialize(log)
  @lines = Hash.new
  
  file = File.open(log)
  header = true
  
  while (line = file.gets)
    line.gsub! /\r*\n/o, ''
    if header
      case line
        when /Listener:\s(.*)/
          #logger.info "Listener is: #{Regexp.last_match(1)}"
          @owner = Regexp.last_match(1)
        when /Session\sstarted:\s(.*)/
          #logger.info "Session started at: #{Regexp.last_match(1)}"
          @session_start = Regexp.last_match(1)
          #puts generateUrl(log.id)              
          #log.hash = generateUrl(log.id)

          header = false
          file.gets
          next
      end
    else
      line.gsub! /\[\s(.*)\s\]\s\((.*?)\)\s/o, ''
      type = $2

      Regexp.last_match(1) =~ /(\d{4})\.(\d{2})\.(\d{2}) (\d{2}):(\d{2}):(\d{2})/o
      time = Time.mktime($1, $2, $3, $4, $5, $6)
      
      case type
        
        when "notify"
          entry = NotifyLine.new(time)

          case line
            when /(You|.*?) (?:has|have) started trying to warp scramble "{0,1}(you|.*)"{0,1}/o
#            when /(.*?) has started trying to warp scramble \"(.*?)\"/
              entry.action = NotifyLine::Action::Scramble
              entry.arg1 = Line::Name.new(Regexp.last_match(1) == "You" ? self.owner : Regexp.last_match(1))
              
              entry.arg2 = Line::Name.new(Regexp.last_match(2) == "You" ? self.owner : Regexp.last_match(2))
              #puts "#{Regexp.last_match(1)} scrammed #{Regexp.last_match(2)}"
            when /(.*?) deactivates as (.*?) begins to explode\./o
              entry.action = NotifyLine::Action::Explode
              entry.arg1 = Regexp.last_match(1)
              entry.arg2 = Regexp.last_match(2)
              
              #puts "#{Regexp.last_match(1)} because #{Regexp.last_match(2)} wanished"
            when /Warping to (.*)/
              entry.action = NotifyLine::Action::WarpTo
              entry.arg1 = Regexp.last_match(1)
              #puts "new location: #{Regexp.last_match(1)}"
            when /(.*?) requires (\d+.\d) units of charge. The capacitor has only (\d+.\d) units\./o
              entry.arg1 = Regexp.last_match(1)
              entry.arg2 = Regexp.last_match(2).to_i - Regexp.last_match(3).to_i
              entry.action = NotifyLine::Action::OutOfCap
              #puts "out of cap!"
            when /Loading the (.*?) into the (.*?); this will take approximately 10 seconds\./o
              entry.action = NotifyLine::Action::Reload
              entry.arg1 = Regexp.last_match(1)
              entry.arg2 = Regexp.last_match(2)
              #puts "reload"
            when /(.*?) deactivates because its target, (.*?), is not locked\./o
              entry.action = NotifyLine::Action::NotLocked
              entry.arg1 = Regexp.last_match(1)
              entry.arg2 = Regexp.last_match(2)
              #puts "jammed"
            else
              #puts "unmatched notify line: #{line}"
          end
          entry.text = line
        when 'combat'

          case line
          when /(?:<color=0xffbbbb00>){0,1}Your (.*?) (perfectly strikes|is well aimed at|glances off|lightly hits|barely scratches|hits|places an excellent hit on|places an excellent hit on) (.*)\, (?:wrecking for|doing|causing|inflicting){0,1} (.*) damage\./o
              #puts "hit: #{Regexp.last_match(1)} - #{Regexp.last_match(2)} -  #{Regexp.last_match(3)} - #{Regexp.last_match(4)}"
            when /(?:Your ){0,1}(.*) (barely ){0,1}misses (.*)(completely){0,1}/o
              #puts "miss: #{Regexp.last_match(1)} - #{Regexp.last_match(2)}  - #{Regexp.last_match(3)}  - #{Regexp.last_match(4)}"
            when /(?:<color=0xffbb6600>){0,1}(.*) (strikes|barely scratches|places an excellent hit on|aims well at|hits) you(?:  perfectly){0,1}, (?:wrecking for|causing|doing|inflicting) (.*) damage\./o
              #puts "got hit: #{Regexp.last_match(1)} - #{Regexp.last_match(2)} - #{Regexp.last_match(3)} - #{Regexp.last_match(4)}"
            when /(.*) (lands a hit on you which glances off, causing no real damage|misses you completely|barely misses you)\./o
              #puts "glance off: #{Regexp.last_match(1)} - #{Regexp.last_match(2)} - #{Regexp.last_match(3)} - #{Regexp.last_match(4)}"
            else
              #puts "unmatched combat line: #{line}"
          end
          entry = CombatLine.new(time, Regexp.last_match(1), 
                            Regexp.last_match(2), 
                            Regexp.last_match(3) == "You" ? self.owner : Regexp.last_match(3), 
                            Regexp.last_match(4), line)
        when 'question'
          #puts "unmatched question line: #{line}"
        when 'info'
          #puts "unmatched info line: #{line}"
        else
          #puts "completely missed line: #{Regexp.last_match(1)} - #{Regexp.last_match(2)} - #{Regexp.last_match(3)} - #{Regexp.last_match(4)} - #{Regexp.last_match(0)}"
      end
      @lines[entry.timestamp.strftime '%Y%m%d%H%M%S'] = entry
    end
  end
end

    end
  
    class Line
      class Type
        Notify=0
        Combat=1
        Question=2
        Info=3
      end
      
      class State
        Unknown=0
        Warping=1
        InFight=2
        Jammed=3
      end
      
      class Name
        attr_accessor :name, :corporation, :alliance, :ship
        
        def initialize(string)
          if string =~ /(.*?) \[(.*?)\]\((.*?)\)/
            @name = Regexp.last_match(1)
            @corporation = Regexp.last_match(2)
            @ship = Regexp.last_match(3)
          elsif string =~ /(.*?) &lt;(.*?)&gt;\((.*?)\)/
            @name = Regexp.last_match(1)
            @alliance = Regexp.last_match(2)
            @ship = Regexp.last_match(3)
          else
            @name = string
          end
        end
      end
      
      attr_accessor :type, :state, :timestamp
      
      def initialize(timestamp)
        @timestamp = timestamp
      end
      
    end
    
    class CombatLine < Line
      attr_accessor :weapon, :group, :hit, :target, :damage, :text
      
      def initialize(timestamp, m1, m2, m3, m4, text)
        super(timestamp)
        self.type = Line::Type::Combat
        
        if m1.gsub! /group of /, ''
          @group = true
        else
          @group = false
        end
        @weapon = m1
        m2.gsub! /is /, ''
        @hit = m2
        @target = Line::Name.new(m3)
        @damage = m4.to_f
        @text = text
      end
    end
    
    
    class NotifyLine < Line
      class Action
        Scramble=0
        Explode=1
        WarpTo=2
        OutOfCap=3
        Reload=4
        NotLocked=5
      end

      attr_accessor :action, :arg1, :arg2, :text
      
      def initialize(timestamp)
        super(timestamp)
        self.type = Line::Type::Notify
      end
    end
  end
end
