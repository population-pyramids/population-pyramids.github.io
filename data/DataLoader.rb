require 'nokogiri'
require 'json'

module DataLoader
  @@regions = nil
   
  def self.loadData()
    if @@regions.nil?
      unless File.exist? "data.json"
        @@regions = self.loadRegions()
        
        File.open('data.json', 'w') {|f| f.write(JSON.dump(@@regions)) }
        return @@regions
      else
        file = File.open('data.json').read
        @@regions = JSON.parse(file)
        return @@regions
      end
    else
      return @@regions    
    end
  end
  
  def self.loadRegions()
    attribs = buildDictionary()
    
    puts "Starting load"
    doc = Nokogiri::XML::Reader(File.open("data/Generic_98-311-XCB2011021.xml"))
    puts "File handle loaded"
    puts "Beginning parse"
    
    hash_maker = proc do |h, k|
      h[k] = Hash.new(&hash_maker)
    end
    
    regions = Hash.new(&hash_maker)
    
    region_total = {}
    
    element = nil
    
    doc.each do |node|
      if node.name == "generic:Series"
        
        if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
          element = {}
        
        elsif node.node_type == Nokogiri::XML::Reader::TYPE_END_ELEMENT
          if element.include? 'age'
            region_id = element['region_id']
            age = element['age']
            sex = element['sex']
            people = element['value']
            
            if age == 'total'
              region_total[region_id] = people.to_f
            else
              regions[region_id][age]['age'] = age
              regions[region_id][age][sex] = {'people' => people}
               
              total = region_total[region_id]
              if total
                percent = (people.to_f / total) * 100
                regions[region_id][age][sex]['percentOfTotal'] = percent   
              end
            end
          end  
        end
        
      elsif node.name == "generic:Value"
        
        if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
          
          if node.attribute("concept") == "GEO"
            
            region_id = node.attribute("value")
            element["region_id"] = region_id
            element["region"] = attribs["geo"][region_id]
            
          elsif node.attribute("concept") == "AGE"
            
            age_id = node.attribute("value")
            age = attribs["age"][age_id]
            age = age.gsub("Total - Age","total")
            age = age.gsub("Under 1 year","<1")
            age = age.gsub("100 years and over","100+")
            
            if /^\d*$|total|\<1|100\+/.match(age)
              element["age"] = age
            end  
          
          elsif node.attribute('concept') == 'Sex'
            
            sex_id = node.attribute('value')
            element['sex'] = attribs['sex'][sex_id].downcase.sub(" - sex",'') 
            
          end  
        end
        
      elsif node.name == 'generic:ObsValue'
        
        element['value'] = node.attribute('value')
      
      end
      
    end
    puts regions
    output = {}
    regions.each_key do |region_id|
      output[region_id] = regions[region_id].values
    end
    
    return output
  end
  
  def self.buildDictionary(language = "en")
    dict = {}
    doc = Nokogiri::XML(File.open("data/Structure_98-311-XCB2011021.xml"))
    doc.remove_namespaces!
    
    doc.css('CodeList').each do |codeList|
      id = codeList[:id]
      id = id.gsub("CL_","").downcase
      
      codeListDict = {}
      codeList.css('Code').each do |code|
        value = code[:value]
        
        codeDesc = nil
        code.xpath('Description').each do |desc|
          lang = desc[:lang]
          
          if lang 
            if lang == language
              codeDesc = desc.content.strip
            end  
          else
            codeDesc = desc.content.strip
          end
        end
        codeListDict[value] = codeDesc     
      end        
      dict[id] = codeListDict
    end
    return dict 
  end   
end

if __FILE__ == $0
  listings = DataLoader.loadData()
  puts listings.length
  #puts DataLoader.findAttributeValueForKey("sex","1")
end