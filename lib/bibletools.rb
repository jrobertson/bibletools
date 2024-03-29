#!/usr/bin/env ruby

# file: bibletools.rb

require 'rexle'
require 'yawc'
require 'nokorexi'

require 'cerecvoice2019'
require 'english_spellchecker'


BOOKS = [
  "Genesis",
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
  "Revelation"
]

module BibleTools

  class ScraperErr < Exception
  end
  
  class Scraper

    def initialize(book: 'Exodus', url: '', debug: false)
      
      raise ScraperErr, 'Please specify the URL' if url.empty?
      
      baseurl = url

      id = if book.is_a? String then
        i = BOOKS.index(book.gsub(/\b./){|x| x.upcase})
        puts 'book *' + book + '* not found' unless i
        (i + 1).to_s
      else
        book.to_s
      end
      
      puts 'id: ' + id.inspect if @debug

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
    
    def save(title)
      
      filename = title.downcase.gsub(/\s+/,'-') + '.xml'      
      File.write filename, @doc.root.xml(pretty: true)
      puts filename +' saved!'
      
    end

  end
  
  class Analyse
    
    def initialize(bible_obj, tts: nil, debug: false)
      
      @debug = debug
      
      if bible_obj then
        
        @doc = bible_obj.to_doc
        @check = EnglishSpellcheck.new debug: false #verbose: false
        
        if tts then
          @cerevoice = Cerecvoice2019.new accountid: tts[:account], 
              password: tts[:password], voice: tts[:voice] || 'Stuart'
        end
        
      end
            
      
    end
    
    #   Automatically select verses; verses are selected based upon word 
    # frequency 
    #
    def asr(chapters: [])
      
      r = if chapters.any? then
        
        doc = Rexle.new('<book/>')
                
        chapters.each do |n|
          e2 = @doc.root.element("chapter[@no='#{n.to_s}']")
          doc.root.add e2 if e2
        end
        
        return doc
        
        keyword = wordtally(doc: doc).keys.first
        #return keyword
        #get the wordstally for the chapters
        assoc_r(keyword, doc)
        
      else
        assoc_r()
      end
      
      e = r[1].root.element('chapter/verse')
      verse_no = e.attributes[:no]
      chptr_no = e.parent.attributes[:no]
      
      # we are backtracking the results to hopefully find a new branch to explore
      trail = r.first

      #return r
      a, trail2 = mine_words(r, trail, level: 2)
      a << [chptr_no, verse_no,  e.text, 1]
      puts 'a: ' + a.inspect
      #return a
      h = a.group_by(&:first)
      a2 = h.sort_by {|x, _| x.to_i}
      @verses = a2.map do |chapter, verses|
        [chapter, verses.sort_by {|_,x| x.to_i}]
      end
        
      [@verses, trail2]
    end    
    
    # find the words associated with a given keyword
    # 
    def assoc(keyword, doc=@doc)
      doc2 = self.search keyword, doc
      [self.words(doc: doc2), doc2]
    end
    
    def assoc_r(keyword=words().keys.first, doc=@doc, list=[], results=[])
      
      result = assoc(keyword, doc)
      results << result
      h, doc2 = result
      new_keyword = h.keys.find {|x| not list.include? x}
      return [list, doc2, results] unless new_keyword
      
      list << new_keyword
      assoc_r(new_keyword, doc2, list, results)
      
    end
    
    def custom_words(doc: @doc, level: 3)
            
      a = wordtally(level: level, doc: doc).keys.map do |word|
        puts 'word: ' + word.inspect if @debug
        [word, @check.spelling(word, verbose: false)]
      end
      
      a2 = a.select do |w, x| 
        if x.is_a? String then
          w != x
        elsif x.is_a? Array
          not (w == x.join or w == x.first)
        else
          true
        end
      end
      a2.map(&:first)
      
    end
    
    def wordtally(level: 2, doc: @doc)
      
      return unless doc
      Yawc.new(doc.root.plaintext, level: level).to_h
      
    end
    
    alias words wordtally
    
    def read(chapter, verse)
      
      if verse.is_a? Integer then
        [@doc.root.element("chapter[@no='#{chapter}']/verse[@no='#{verse}']")]
      elsif verse.is_a? Array
        verse.map do |x|
          @doc.root.element("chapter[@no='#{chapter}']/verse[@no='#{x}']")
        end
      end
    end


    def search(keyword, doc=@doc)
      
      verses = doc.root.xpath('chapter/verse')
      puts 'verses: ' + verses.inspect
      a = verses.select {|x| x.text =~ /#{keyword}/i}
      
      a2 = a.map.with_index do |verse, i|
        
        #puts 'verse: ' + verse.xml.inspect
        txt = verse.text
        
        puts 'txt: ' + txt.inspect if @debug
        
        n = 0
        chapter = verse.parent.attributes[:no]
        
        until txt.rstrip[/[\.\?!]\W*$/] or n > 2 do
          n +=1
          puts 'n: ' + n.inspect
          nverse = read(chapter, verse.attributes[:no].to_i + n)[0]
          puts 'nverse: ' + nverse.inspect
          puts 'nverse: ' + nverse&.text.inspect if @debug
          txt += nverse.text if nverse
        end 
        
        if @debug then
          puts 'n: ' + n.inspect
          puts '_txt: ' + txt.inspect
        end
        
        [verse.parent.attributes[:no], verse.attributes[:no], txt]
      end

      # group by chapter
      #
      h = a2.group_by(&:first)      
      
      doc = Rexle.new('<book/>')

      h.each do |key, value|

        echapter = Rexle::Element.new('chapter', attributes: {no: key})

        value.each do |_, verse_no, verse|
          everse = Rexle::Element.new('verse', attributes: {no: verse_no}).add_text verse
          echapter.add everse
        end

        doc.root.add echapter

      end
      
      return doc
      
    end
    
    def tts(chapter, verse)
      
      verses = read(chapter, verse).map(&:text).join(' ')
      @cerevoice.tts verses, out: 'tts.ogg'      
      
    end
    
    def verses(level: nil, html: false, title: nil)                  

      a = @verses.map {|_, body| body}.flatten(1)
      a1 = level ? a.select {|c,v,t,l| l <= level} : a.map {|c,v,t,l| [c,v,t]}
      a2 = a1.map {|c,v,t,l| [c,v,t]}.uniq
      h = a2.group_by(&:first)
      
      puts 'html: ' + html.inspect
      return h unless html == true
      
      doc = Rexle.new('<html/>')


      head = Rexle::Element.new('head')
      head.add(Rexle::Element.new('h1').add_text(title) ) if title

      style = Rexle::Element.new('style')
      style.add_text '     ins {font-size: 0.8em;padding: 0.8em;}'
      head.add style

      doc.root.add head
      body = Rexle::Element.new('body')

      h.each do |chptr, verses|

        h2 = Rexle::Element.new('h2').add_text chptr
        body.add h2

        verses.each do |cno, vno, text|

          ins = Rexle::Element.new('ins').add_text vno
          para = Rexle::Element.new('p')
          para.add ins
          para.add_text text
          body.add para
          
        end
        
      end
      
      doc.root.add body

      doc.root.xml pretty: true
      
    end
    
    private

    def mine_words(r, trail, verses=[], level: 0)

      i = 0
      found = []
      (i-=1; found = r.last[i][0].keys - trail) until found.any?
      r2 = r.last[i][0].keys - trail
      
      a3 = r2.map do |x|
        
        _, doc_verse = assoc_r x, r.last[i][1]
        chaptr_no = doc_verse.root.element('chapter').attributes[:no]
        everse = doc_verse.root.element('chapter/verse')
        verse_no = everse.attributes[:no]
        
        [chaptr_no, verse_no, everse.text, level]
        
      end.uniq

      puts 'verses: ' + verses.inspect if @debug
      
      verses.concat a3
      verses.uniq!
      trail.concat r2
      
      puts 'trail.length: ' + trail.length.inspect if @debug
      puts 'verses.length: ' + verses.length.inspect if @debug

      if verses.length > 30 or trail.length > 100
        [verses, trail]
      else

        mine_words(r, trail, verses, level: level+1)        
      end
    end    
    
  end

end
