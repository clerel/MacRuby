# -*- mode: ruby; ruby-indent-level: 4; tab-width: 4 -*- vim: sw=4 ts=4
require 'date'
require 'libyaml'

class Class
  def to_yaml(out=nil)
    raise TypeError, "can't dump anonymous class %s" % self.class
  end
end

class Object

  def yaml_as(tag)
    klass = (self.is_a? Class) ? self : (class << self; self; end)
    klass.instance_eval do
      define_method(:taguri) do
        @taguri || tag
      end
    end
    YAML::LibYAML::DEFAULT_RESOLVER.add_type(tag, self)
  end

  #yaml_as "tag:ruby.yaml.org,2002:object"
  
  def to_yaml_style
    nil
  end
  
  def to_yaml_properties
    self.instance_variables.sort
  end
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.map(taguri, to_yaml_style) do |map|
        to_yaml_properties.each do |m|
          # The [1..-1] strips the @ from the variable name.
          out.add(m[1..-1], instance_variable_get(m))
        end
      end
    end
  end

  def self.yaml_new(val)
    obj = self.alloc
    if obj.respond_to?(:yaml_initialize)
      obj.yaml_initialize(taguri, val)
    else
      val.each do |k, v|
        obj.instance_variable_set("@#{k}", v)
      end
    end
    obj
  end

  private

  def taguri; "!ruby/object:#{self.class}"; end
end

class Struct
  yaml_as "tag:ruby.yaml.org,2002:struct"

  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.map(taguri, to_yaml_style) do |map|
        members.each do |m|
          out.add(m.to_s, self[m])
        end
      end
    end
  end

  def self.yaml_new(val)
    obj = self.new
    val.each { |k, v| obj[k] = v }
    obj
  end

  private

  def taguri; "!ruby/struct:#{self.class.to_s.sub(/^Struct::/, '')}"; end
end

class String
  yaml_as "tag:yaml.org,2002:str"
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.scalar(taguri, self, to_yaml_style)
    end
  end

  def self.yaml_new(val); val; end
end

class Exception
  yaml_as "tag:ruby.yaml.org,2002:exception"

  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.map(taguri, to_yaml_style) do |map|
        map.add('message', message)
      end
    end
  end

  def taguri; "!ruby/exception:#{self.class}"; end
end

class Array
  yaml_as "tag:yaml.org,2002:seq"
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.seq(taguri, to_yaml_style) do |seq|
        each { |i| seq.add(i) }
      end
    end
  end
end

class Hash
  yaml_as "tag:yaml.org,2002:map"
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.map(taguri, to_yaml_style) do |map| 
        each { |k,v| map.add(k,v) }
      end
    end
  end
end

class Integer
  yaml_as "tag:yaml.org,2002:int"
  
  def Integer.yaml_new(val)
    val.to_i
  end
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.scalar("tag:yaml.org,2002:int", self.to_s, :plain)
    end
  end
end

class Float
  yaml_as "tag:yaml.org,2002:float"
  
  def Float.yaml_new(val)
    val.to_f
  end
  
  def to_yaml(output = nil)
    str = self.to_s
    if str == "Infinity"
      str = ".Inf"
    elsif str == "-Infinity"
      str = "-.Inf"
    elsif str == "NaN"
      str = ".NaN"
    end
    YAML::quick_emit(output) do |out|
      out.scalar("tag:yaml.org,2002:float", str, :plain)
    end
  end
end

class Symbol
  yaml_as "tag:ruby.yaml.org,2002:symbol"
  
  def self.yaml_new(val); val[1..-1].to_sym; end
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.scalar(taguri, self.inspect, :plain)
    end
  end
end

class Range
  yaml_as "tag:ruby.yaml.org,2002:range"
  
  def Range.yaml_new(attrs)
    Range.new(attrs['begin'], attrs['end'], attrs['excl'])
  end
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.map(taguri, to_yaml_style) do |map|
        map.add('begin', self.begin)
        map.add('end', self.end)
        map.add('excl', self.exclude_end?)
      end
    end
  end
end

class Regexp
  yaml_as "tag:ruby.yaml.org,2002:regexp"

  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.scalar(taguri, self.inspect, :plain)
    end
  end
end

class Rational
  yaml_as "tag:ruby.yaml.org,2002:object:Rational"
  
  def Rational.yaml_new(attrs)
    if attrs.is_a? String
      Rational(attrs)
    else
      Rational(attrs['numerator'], attrs['denominator'])
    end
  end
  
  def to_yaml(output = nil) 
    YAML::quick_emit(output) do |out|
      out.map(taguri, to_yaml_style) do |map| 
        map.add('denominator', denominator)
        map.add('numerator', numerator)
      end
    end
  end
end

class Complex
  yaml_as "tag:ruby.yaml.org,2002:object:Complex"
  def Complex.yaml_new(val)
    if val.is_a? String
      Complex(val)
    else
      Complex(val['real'], val['image'])
    end
  end
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.map(taguri, nil ) do |map|
        map.add('image', imaginary)
        map.add('real', real)
      end
    end
  end
end

class NilClass 
  yaml_as "tag:yaml.org,2002:null"
  
  def self.yaml_new(val); nil; end
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.scalar(taguri, "", :plain)
    end
	end
end

class TrueClass
  yaml_as "tag:yaml.org,2002:true"
  
  def self.yaml_new(val); true; end
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.scalar(taguri, "true", :plain)
    end
  end
end

class FalseClass
  yaml_as "tag:yaml.org,2002:false"
  
  def self.yaml_new(val); false; end
  
  def to_yaml(output = nil)
    YAML::quick_emit(output) do |out|
      out.scalar(taguri, "false", :plain)
    end
  end
end

class DateTime
    yaml_as "tag:yaml.org,2002:timestamp"
    def self.yaml_new(val)
        if val.length <= 10
            Date.strptime(val)
        else
            format = "%F %T"
            if val =~ /([tT])/
                format = "%F#{$1}%T"
            end
            if val =~ /\./
                format += ".%N%z"
            else
                format += "%z"
            end
            val = val.tr(" \t", "")
            if val !~ /(Z|[-+]\d\d?(?::\d\d)?)$/
                val = val + "Z"
            end
            strptime(val, format).to_time
        end
    end
    def to_yaml(output = nil)
        to_time.to_yaml(output)
    end
end

class Time
	def to_yaml(output = nil)
        # Not exactly canonical YAML format, but legal, and consistent with syck
		YAML::quick_emit(output) do |out|
            tz = "Z"
            # from the tidy Tobias Peters <t-peters@gmx.de> Thanks!
            unless self.utc?
                utc_same_instant = self.dup.utc
                utc_same_writing = Time.utc(year,month,day,hour,min,sec,usec)
                difference_to_utc = utc_same_writing - utc_same_instant
                if (difference_to_utc < 0) 
                    difference_sign = '-'
                    absolute_difference = -difference_to_utc
                else
                    difference_sign = '+'
                    absolute_difference = difference_to_utc
                end
                difference_minutes = (absolute_difference/60).round
                tz = "%s%02d:%02d" % [ difference_sign, difference_minutes / 60, difference_minutes % 60]
            end
            standard = self.strftime( "%Y-%m-%d %H:%M:%S" )
            standard += ".%06d" % [usec] if usec.nonzero?
            standard += " %s" % [tz]
            out.scalar("tag:yaml.org,2002:timestamp", standard, :plain)
        end
	end
end

class Date
	def to_yaml(output = nil)
		YAML::quick_emit(output) do |out|
            out.scalar("tag:yaml.org,2002:timestamp", self.to_s, :plain)
        end
	end
end

=begin

class Hash
    yaml_as "tag:ruby.yaml.org,2002:hash"
    yaml_as "tag:yaml.org,2002:map"
    def yaml_initialize( tag, val )
        if Array === val
            update Hash.[]( *val )		# Convert the map to a sequence
        elsif Hash === val
            update val
        else
            raise YAML::TypeError, "Invalid map explicitly tagged #{ tag }: " + val.inspect
        end
    end
	def to_yaml( opts = {} )
		YAML::quick_emit( self, opts ) do |out|
            out.map( taguri, to_yaml_style ) do |map|
                each do |k, v|
                    map.add( k, v )
                end
            end
        end
	end
end

class Struct
    yaml_as "tag:ruby.yaml.org,2002:struct"
    def self.yaml_tag_class_name; self.name.gsub( "Struct::", "" ); end
    def self.yaml_tag_read_class( name ); "Struct::#{ name }"; end
    def self.yaml_new( klass, tag, val )
        if Hash === val
            struct_type = nil

            #
            # Use existing Struct if it exists
            #
            props = {}
            val.delete_if { |k,v| props[k] = v if k =~ /^@/ }
            begin
                struct_name, struct_type = YAML.read_type_class( tag, Struct )
            rescue NameError
            end
            if not struct_type
                struct_def = [ tag.split( ':', 4 ).last ]
                struct_type = Struct.new( *struct_def.concat( val.keys.collect { |k| k.intern } ) ) 
            end

            #
            # Set the Struct properties
            #
            st = YAML::object_maker( struct_type, {} )
            st.members.each do |m|
                st.send( "#{m}=", val[m] )
            end
            props.each do |k,v|
                st.instance_variable_set(k, v)
            end
            st
        else
            raise YAML::TypeError, "Invalid Ruby Struct: " + val.inspect
        end
    end
	def to_yaml( opts = {} )
		YAML::quick_emit( self, opts ) do |out|
			#
			# Basic struct is passed as a YAML map
			#
            out.map( taguri, to_yaml_style ) do |map|
				self.members.each do |m|
                    map.add( m, self[m] )
                end
				self.to_yaml_properties.each do |m|
                    map.add( m, instance_variable_get( m ) )
                end
            end
        end
	end
end

class Exception
    yaml_as "tag:ruby.yaml.org,2002:exception"
    def Exception.yaml_new( klass, tag, val )
        o = YAML.object_maker( klass, { 'mesg' => val.delete( 'message' ) } )
        val.each_pair do |k,v|
            o.instance_variable_set("@#{k}", v)
        end
        o
    end
	def to_yaml( opts = {} )
		YAML::quick_emit( self, opts ) do |out|
            out.map( taguri, to_yaml_style ) do |map|
                map.add( 'message', message )
				to_yaml_properties.each do |m|
                    map.add( m[1..-1], instance_variable_get( m ) )
                end
            end
        end
	end
end

class String
    yaml_as "tag:ruby.yaml.org,2002:string"
    yaml_as "tag:yaml.org,2002:binary"
    yaml_as "tag:yaml.org,2002:str"
    def is_complex_yaml?
        to_yaml_style or not to_yaml_properties.empty? or self =~ /\n.+/
    end
    def is_binary_data?
        ( self.count( "^ -~", "^\r\n" ).fdiv(self.size) > 0.3 || self.index( "\x00" ) ) unless empty?
    end
    def String.yaml_new( klass, tag, val )
        val = val.unpack("m")[0] if tag == "tag:yaml.org,2002:binary"
        val = { 'str' => val } if String === val
        if Hash === val
            s = klass.allocate
            # Thank you, NaHi
            String.instance_method(:initialize).
                  bind(s).
                  call( val.delete( 'str' ) )
            val.each { |k,v| s.instance_variable_set( k, v ) }
            s
        else
            raise YAML::TypeError, "Invalid String: " + val.inspect
        end
    end
	def to_yaml( opts = {} )
		YAML::quick_emit( is_complex_yaml? ? self : nil, opts ) do |out|
            if is_binary_data?
                out.scalar( "tag:yaml.org,2002:binary", [self].pack("m"), :literal )
            elsif to_yaml_properties.empty?
                out.scalar( taguri, self, self =~ /^:/ ? :quote2 : to_yaml_style )
            else
                out.map( taguri, to_yaml_style ) do |map|
                    map.add( 'str', "#{self}" )
                    to_yaml_properties.each do |m|
                        map.add( m, instance_variable_get( m ) )
                    end
                end
            end
        end
	end
end

class Symbol
    yaml_as "tag:ruby.yaml.org,2002:symbol"
    yaml_as "tag:ruby.yaml.org,2002:sym"
    def Symbol.yaml_new( klass, tag, val )
        if String === val
            val = YAML::load( val ) if val =~ /\A(["']).*\1\z/
            val.intern
        else
            raise YAML::TypeError, "Invalid Symbol: " + val.inspect
        end
    end
	def to_yaml( opts = {} )
		YAML::quick_emit( nil, opts ) do |out|
            out.scalar( "tag:yaml.org,2002:str", self.inspect, :plain )
        end
	end
end

class Range
    yaml_as "tag:ruby.yaml.org,2002:range"
    def Range.yaml_new( klass, tag, val )
        inr = %r'(\w+|[+-]?\d+(?:\.\d+)?(?:e[+-]\d+)?|"(?:[^\\"]|\\.)*")'
        opts = {}
        if String === val and val =~ /^#{inr}(\.{2,3})#{inr}$/o
            r1, rdots, r2 = $1, $2, $3
            opts = {
                'begin' => YAML.load( "--- #{r1}" ),
                'end' => YAML.load( "--- #{r2}" ),
                'excl' => rdots.length == 3
            }
            val = {}
        elsif Hash === val
            opts['begin'] = val.delete('begin')
            opts['end'] = val.delete('end')
            opts['excl'] = val.delete('excl')
        end
        if Hash === opts
            r = YAML::object_maker( klass, {} )
            # Thank you, NaHi
            Range.instance_method(:initialize).
                  bind(r).
                  call( opts['begin'], opts['end'], opts['excl'] )
            val.each { |k,v| r.instance_variable_set( k, v ) }
            r
        else
            raise YAML::TypeError, "Invalid Range: " + val.inspect
        end
    end
	def to_yaml( opts = {} )
		YAML::quick_emit( self, opts ) do |out|
            # if self.begin.is_complex_yaml? or self.begin.respond_to? :to_str or
            #   self.end.is_complex_yaml? or self.end.respond_to? :to_str or
            #   not to_yaml_properties.empty?
                out.map( taguri, to_yaml_style ) do |map|
                    map.add( 'begin', self.begin )
                    map.add( 'end', self.end )
                    map.add( 'excl', self.exclude_end? )
                    to_yaml_properties.each do |m|
                        map.add( m, instance_variable_get( m ) )
                    end
                end
            # else
            #     out.scalar( taguri ) do |sc|
            #         sc.embed( self.begin )
            #         sc.concat( self.exclude_end? ? "..." : ".." )
            #         sc.embed( self.end )
            #     end
            # end
        end
	end
end

class Regexp
    yaml_as "tag:ruby.yaml.org,2002:regexp"
    def Regexp.yaml_new( klass, tag, val )
        if String === val and val =~ /^\/(.*)\/([mix]*)$/
            val = { 'regexp' => $1, 'mods' => $2 }
        end
        if Hash === val
            mods = nil
            unless val['mods'].to_s.empty?
                mods = 0x00
                mods |= Regexp::EXTENDED if val['mods'].include?( 'x' )
                mods |= Regexp::IGNORECASE if val['mods'].include?( 'i' )
                mods |= Regexp::MULTILINE if val['mods'].include?( 'm' )
            end
            val.delete( 'mods' )
            r = YAML::object_maker( klass, {} )
            Regexp.instance_method(:initialize).
                  bind(r).
                  call( val.delete( 'regexp' ), mods )
            val.each { |k,v| r.instance_variable_set( k, v ) }
            r
        else
            raise YAML::TypeError, "Invalid Regular expression: " + val.inspect
        end
    end
	def to_yaml( opts = {} )
		YAML::quick_emit( nil, opts ) do |out|
            if to_yaml_properties.empty?
                out.scalar( taguri, self.inspect, :plain )
            else
                out.map( taguri, to_yaml_style ) do |map|
                    src = self.inspect
                    if src =~ /\A\/(.*)\/([a-z]*)\Z/
                        map.add( 'regexp', $1 )
                        map.add( 'mods', $2 )
                    else
		                raise YAML::TypeError, "Invalid Regular expression: " + src
                    end
                    to_yaml_properties.each do |m|
                        map.add( m, instance_variable_get( m ) )
                    end
                end
            end
        end
	end
end

class Time
    yaml_as "tag:ruby.yaml.org,2002:time"
    yaml_as "tag:yaml.org,2002:timestamp"
    def Time.yaml_new( klass, tag, val )
        if Hash === val
            t = val.delete( 'at' )
            val.each { |k,v| t.instance_variable_set( k, v ) }
            t
        else
            raise YAML::TypeError, "Invalid Time: " + val.inspect
        end
    end
	def to_yaml( opts = {} )
		YAML::quick_emit( self, opts ) do |out|
            tz = "Z"
            # from the tidy Tobias Peters <t-peters@gmx.de> Thanks!
            unless self.utc?
                utc_same_instant = self.dup.utc
                utc_same_writing = Time.utc(year,month,day,hour,min,sec,usec)
                difference_to_utc = utc_same_writing - utc_same_instant
                if (difference_to_utc < 0) 
                    difference_sign = '-'
                    absolute_difference = -difference_to_utc
                else
                    difference_sign = '+'
                    absolute_difference = difference_to_utc
                end
                difference_minutes = (absolute_difference/60).round
                tz = "%s%02d:%02d" % [ difference_sign, difference_minutes / 60, difference_minutes % 60]
            end
            standard = self.strftime( "%Y-%m-%d %H:%M:%S" )
            standard += ".%06d" % [usec] if usec.nonzero?
            standard += " %s" % [tz]
            if to_yaml_properties.empty?
                out.scalar( taguri, standard, :plain )
            else
                out.map( taguri, to_yaml_style ) do |map|
                    map.add( 'at', standard )
                    to_yaml_properties.each do |m|
                        map.add( m, instance_variable_get( m ) )
                    end
                end
            end
        end
	end
end

class Date
    yaml_as "tag:yaml.org,2002:timestamp#ymd"
	def to_yaml( opts = {} )
		YAML::quick_emit( self, opts ) do |out|
            out.scalar( "tag:yaml.org,2002:timestamp", self.to_s, :plain )
        end
	end
end


=end
