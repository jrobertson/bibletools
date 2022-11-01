#!/usr/bin/env ruby

# file: bibletools.rb

require 'rexle'
require 'yawc'
require 'nokorexi'


module BibleTools

  class ScraperErr < Exception
  end
  
  class Scraper

    def initialize(book: 'Exodus', url: '')
      
      raise ScraperErr, 'Please specify the URL' if url.empty?
      
      baseurl = url

      books = ["Genesis",
       "Exodus",
       "Leviticus",                                                                  
       "Numbers",
       "Deuteronomy",
       "Joshua",
       "Judges",
       "Ruth", 
       "1 Samuel",
       "2 Samuel",
       "1 Kings",
       "2 Kings",
       "1 Chronicles",
       "2 Chronicles",
       "Ezra",
       "Nehemiah",
       "Tobit",
       "Judith",
       "Esther",
       "1 Maccabees",
       "2 Maccabees",
       "Job",
       "Psalms",
       "The Proverbs",
       "Ecclesiastes",
       "The Song of Songs",
       "Wisdom",
       "Ecclesiasticus / Sirach",
       "Isaiah",
       "Jeremiah",
       "Lamentations",
       "Baruch",
       "Ezekiel",
       "Daniel",
       "Hosea",
       "Joel",
       "Amos",
       "Obadiah",
       "Jonah",
       "Micah",
       "Nahum",
       "Habakkuk",
       "Zephaniah",
       "Haggai",
       "Zechariah",
       "Malachi",
       "Matthew",                                                                   
       "Mark",  
       "Luke",
       "John",
       "Acts of Apostles",
       "Romans",
       "1 Corinthians", 
       "2 Corinthians",
       "Galatians", 
       "Ephesians",
       "Philippians",
       "Colossians",
       "1 Thessalonians",
       "2 Thessalonians",
       "1 Timothy",
       "2 Timothy",
       "Titus",
       "Philemon",
       "Hebrews",
       "James",
       "1 Peter",
       "2 Peter",
       "1 John",
       "2 John",
       "3 John",
       "Jude",
       "Revelation"]

      id = if book.is_a? String then
        (books.index(book) + 1).to_s
      else
        book.to_s
      end



      url2 = baseurl + '?id=' + id
      doc = Nokorexi.new(url2).to_doc
      e = doc.root.at_css('.pagination')
      endchapter = e.xpath('li')[-2].text('a')


      book = Rexle.new('<book/>')

      (1..endchapter.to_i).each do |chp|

        c = chp.to_s
        puts 'reading chapter ' + c

        sleep 1
        url2 = baseurl + ("?id=%s&bible_chapter=%s" % [id, c])
        doc = Nokorexi.new(url2).to_doc
        a = doc.root.xpath('//div/p')
        a2 = a.select {|e| e2 = e.element('a'); e2.attributes[:name] if e2}

        chapter = Rexle::Element.new('chapter', attributes: {no: c})

        a2.each.with_index do |e, i|

          puts 'processing verse ' + i.to_s
          txt = e.plaintext
          n = txt.slice!(0,2).to_i.to_s
          chapter.add Rexle::Element.new('verse', attributes: {no: n}).add_text(txt)

        end

        book.root.add chapter

      end

      @doc = book

    end

    def to_doc
      @doc
    end

  end
  
  class Analyse
    
    def initialize(bible_obj, debug: false)
      
      @debug = debug
      
      if bible_obj then
        @doc = bible_obj.to_doc
        @verses = @doc.root.xpath('chapter/verse')
      end
      
    end
    
    def wordtally()
      
      return unless @doc
      Yawc.new(@doc.root.plaintext).to_h
      
    end
    
    alias words wordtally
    
    def read(chapter, verse)
      @doc.root.element("chapter[@no='#{chapter}']/verse[@no='#{verse}']")
    end


    def search(keyword)
      
      a = @verses.select {|x| x.text =~ /#{keyword}/}
      
      a2 = a.map.with_index do |verse, i|
        txt = verse.text
        
        puts 'txt: ' + txt.inspect if @debug
        
        n = 0
        chapter = verse.parent.attributes[:no]
        
        until txt.rstrip[-1] == '.' or n > 2 do
          n +=1
          nverse = read(chapter, verse.attributes[:no].to_i + n)
          txt += nverse.text
        end 
        
        if @debug then
          puts 'n: ' + n.inspect
          puts '_txt: ' + txt.inspect
        end
        
        [verse.parent.attributes[:no], verse.attributes[:no], txt]
      end

      h1 = a2.group_by(&:first)
    end
    
    
  end

end

