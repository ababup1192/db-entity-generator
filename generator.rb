# -*- coding: utf-8 -*-
require 'singleton'
require 'fileutils'

# File -> [Text] -> [DriverEntity], [MorphiaEntity], [IciqlEntity]
class EntityReader
  include Singleton
  def read
    csv_files = Dir.glob('*.csv')
    # csv -> [{ファイル名: [行データ]}] -> {ファイル名: [行データ]}
    file_hash = csv_files.map{ |csv_file|
      File.open(csv_file) do |file|
        {"#{csv_file}":
         # 行データをカンマでsplit 余計な空白は削除
         file.each_line.map(
           &->line{
             line.chomp.split(',').map(&:strip)
           }
        )
        }
      end
      # 一つのハッシュにまとめる
    }.inject(&:merge)

    file_hash.map { |file_name, fields|
      [
        DriverEntity.new(file_name, fields),
        IciqlEntity.new(file_name, fields),
        MorphiaEntity.new(file_name, fields)
      ]
    }
  end
end

class EntityWriter
  include Singleton
  def write(entities)
    if Dir.exist?('out') then
      FileUtils.rm_rf('out')
    end

    Dir.mkdir('out')

    entities.flatten.each{ |entity| entity.export }
  end
end

class Entity
  def initialize(file_name, sub_class = nil, fields)
    @class_name = file_name.to_s.split('.')[0]
    @sub_class = sub_class
    @fields = fields
  end

  def print_text
    print_header +
      print_fields +
      "\tpublic #{@class_name}(){}\n\n" +
      print_constructor +
      "}"
  end

  def print_header
    if @sub_class.nil? then
      "public class #{@class_name} {\n"
    else
      "public class #{@class_name} extends #{@sub_class} {\n"
    end
  end

  def print_fields
    @fields.map{ |field|
      "\tpublic #{translate_types(field)} #{field[0]};"
    }.join("\n") + "\n\n"
  end

  def print_constructor
    "\tpublic #{@class_name}(" +
      # 仮引数
      @fields.map{ |field|
        "#{translate_types(field)} #{field[0]}"
    }.join(', ') + "){ \n" +
      # 代入部
      @fields.map{ |field|
        "\t\tthis.#{field[0]} = #{field[0]};"
      }.join("\n") + "\n\t} \n"
  end

  # DBカラム型 -> Java型
  def translate_types(field)
    case field[2]
    when 'Numeric' then
      'Integer'
    when 'Varchar' then
      'String'
    when 'Datetime' then
      'Date'
    else
      field[2]
    end
  end

  def to_s
    print_text
  end

  def export
    File.open("./out/#{@class_name}.java", 'w') do |file|
      file.print(self.to_s)
    end
  end

end

class IciqlEntity < Entity
  def initialize(file_name, fields)
    super(file_name, 'AnnotatedEntity', fields)
  end

  def export
    File.open("./out/#{@class_name}PostgreData.java", 'w') do |file|
      file.print(self.to_s)
    end
  end
end

class MorphiaEntity < Entity
  def initialize(file_name, fields)
    super(file_name, 'MongoEntityBase', fields)
  end

  def export
    File.open("./out/#{@class_name}MongoData.java", 'w') do |file|
      file.print(self.to_s)
    end
  end
end

class DriverEntity < Entity
  def initialize(file_name, fields)
    super(file_name, 'AppEntityBase', fields)
  end

  def export
    File.open("./out/App#{@class_name}Entity.java", 'w') do |file|
      file.print(self.to_s)
    end
  end
end

class Main
  include Singleton

  def run
    entities = EntityReader.instance.read
    EntityWriter.instance.write(entities)
  end
end

Main.instance.run
