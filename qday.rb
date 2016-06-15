#/usr/bin/ruby
# Author    :   Ben Spiessens
# Date      :   May 27 2015
# Summery   :   Sends a thoughtful Question read from a YAML file, AND Email everyday to a list of people.

require 'rubygems'
require 'yaml'
require 'base64'
gem 'logger'; require 'logger'
gem 'mail'; require 'mail'


#DATA_FILE_YAML = "/home/ben/code/qday/Ruby/fulldat.yml"
#$Log_file = "/home/ben/code/qday/Ruby/qday-testing.log"

DATA_FILE_YAML = "fulldat.yml"
$Log_file = "qday-testing.log2"

$QDAY_DOC_SET, $QDAY_DOC_RECP, $QDAY_DOC_QUESTIONS = [], [], []
$IsCompleted, $ForceSend, $Parse, $DontSend = false, false, false, false
$Manual_offset = 0
$Add_msg = ""
$Resend = true
$log = Logger.new($Log_file, "monthly")
$padding = 60
$log_level = "ERROR"

=begin Logger Quick Ref
logger = Logger.new File.new('test.log')
logger.debug "debugging info"               # Won't Use
logger.info "general logs"
logger.warn "oh my…this isn't good"
logger.error "boom!"
logger.fatal "oh crap…"                     # Won't Use - Compiler Error

=end

def check_required_files?
    if ( File.exist?(DATA_FILE_YAML) || File.exist?(DATA_FILE_YAML))
        true
    else
        false
    end
end

def internet_connection?
    require 'open-uri'
    begin
        true if open("http://www.google.com/")
    rescue
        false
    end
end

    # To Ensure the gem logger is actually doing the job of changing the log over monthly
    # If it's not take over and just get it done.
def check_log_date
    if ( File.exist?($Log_file) )
        @newlogyear, @newlogmonth, @newlogday, @newlogfilename = String.new
        @logfiletime = File.atime($Log_file)
        @newlogyear = Time.now.localtime("-05:00").year.to_s
        @newlogmonth = Time.now.localtime("-05:00").month.to_s
        @newlogday = (Time.now.localtime("-05:00").day.to_i - 1).to_s
        if ( @newlogmonth.size < 2 ); @newlogmonth = 0.to_s + @newlogmonth; end
        if ( @newlogday.size < 2 ); @newlogday = 0.to_s + @newlogday; end
        @convertnewdates = @newlogyear + @newlogmonth + @newlogday
        @convertolddate = File.atime($Log_file).year.to_s + File.atime($Log_file).month.to_s + File.atime($Log_file).day.to_s
        @newlogfilename = $Log_file + "." + @convertnewdates
        @int_append = 0
        if ( @convertolddate < @convertnewdates )
            while (File.exist?(@newlogfilename))
                @int_append += 1
                @newlogfilename += "(" + @int_append + ")"
            end
            File.rename($Log_file,@newlogfilename)
            $log = Logger.new(@newlogfilename, "monthly")
            if (File.exist?(@newlogfilename))
                puts ("New File name #{@newlogfilename} CONFIRMED!")
            else
                puts ("File name has not been changed!")
            end
        end
    end
end

def send_emails(input_file, recipients, subject_line, message)
    # import smtp settings data from input_file
    options = { :address              => input_file[0],
                :port                 => input_file[1].to_i,
                :domain               => input_file[2],
                :user_name            => input_file[3],
                :password             => input_file[4],
                :authentication       => input_file[5],
                :enable_starttls_auto => input_file[6]  }
    
    if ( subject_line == nil || subject_line == "" )
        subject_line = input_file[7]
    end

    Mail.defaults do
        delivery_method :smtp, options
    end

    Mail.deliver do
        to options[:user_name]
        bcc recipients
        from 'Question of the day'
        subject subject_line
        body message
    end
end

    # Look through the log file and find any errors & send an email to me if there is
def auto_parse_log_file(logfilepath)
    if !( File.exist?(logfilepath) )
        puts ("Cannot Parse Log File.\nLog File Does Not Exist!!\n\n")
        exit()
    end
    logfiledata, error_dates = [], []
    parsed_message = String.new
    logfile = File.open(logfilepath)
    logfile.each{|lines|
                 logfiledata << lines }
    logfile.close

    # Isolate & Extract the Date of the error from the string
    logfiledata.each{|line|
                     if ( line.include?($log_level) )
                         extract = line[4,10]
                         error_dates << extract
                     end }
    error_dates.uniq!

    # seven_days_ago = Time array is made up of :  [0 sec,1 min,2 hour,3 day,4 month,5 year,6 wday,7 yday,8 isdst,9 zone]
    # error_dates && not_in_this_week = 2015-12-20 {String of year-month-day}
    seven_days_ago = Time.now.localtime("-05:00").to_a
    error_dates.each{|not_in_this_week|
                @check_year = not_in_this_week.to_s[0...4]
                @check_month = not_in_this_week.to_s[5...7]
                @check_day = not_in_this_week.to_s[8...10]
                if ( Time.new( @check_year, @check_month, @check_day ).yday < ( seven_days_ago[7] - 7 ))
                    error_dates.delete(not_in_this_week)
                end }

    logfiledata.each{|line|
                    error_dates.each{|dates|
                         if ( line.include?(dates.to_s) )
                            parsed_message << line
                         end }
                     }
    parsed_message += "\n\nCurrent offset of today : #{Time.now.localtime("-05:00").yday}\nTodays's Date is : #{Time.now.localtime("-05:00")}\n"
    if (error_dates.empty?)
        return nil
    else
        return parsed_message
    end
end

def ret_yday
    puts ("The Number of Day in the Year is: #{Time.now.localtime("-05:00").yday}")
    $log.info('ret_yday') {"The Number of Day in the Year is: " + Time.now.localtime("-05:00").yday.to_s}
    $log.info('ret_yday') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s }
    $log.info('ret_yday') {"----- END -----\n\n\n"}
    exit()
end

    # Data Scrubbing for $Manual_offset
def check_yday(chkyday)
    if ( chkyday.integer? && chkyday > 0 && chkyday < 366 )
        $Manual_offset = chkyday
    else
        puts ("The Provided yDay is invalid. Exitting...")
        $log.error('check_yday') {"The Provided yDay is invalid." + chkyday }
        $log.info('check_yday') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s }
        $log.info('check_yday') {"----- END -----\n\n\n"}
        exit()
    end
end

    # Convert Date to a yday and exit
def ret_date(cvtDate)
    @cvtDateStr, @date_breakdown_yr, @date_breakdown_mo, @date_breakdown_dy = "", "", "", ""
    @cvtDateStr = cvtDate.to_s
    @date_breakdown_yr = @cvtDateStr[0..3]  # Year
    @date_breakdown_mo = @cvtDateStr[5..6]  # Month
    @date_breakdown_dy = @cvtDateStr[8..9]  # Day
    begin
        if ( @cvtDateStr.size < 10 )
            raise ArgumentError
        end
            $Manual_offset = Time.new(@date_breakdown_yr, @date_breakdown_mo, @date_breakdown_dy).localtime("-05:00").yday
    rescue ArgumentError => err
        puts ("The Provided Date is out of range for a date #{cvtDate}. ")
        puts ("Ensure the date follows yyyy-mm-dd eg. 1998-02-25 or 2005-11-08")
        puts (" Exitting...")
        $log.error('ret_date') {"The Provided Date is out of range." + cvtDate}
        $log.error('ret_date') {"Information Dump" + err.message + "\n" + err.backtrace.inspect + "\n"}
        $log.info('ret_date') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s}
        $log.info('ret_date') {"----- END -----\n\n\n"}
        exit()
    end
    $DontSend = true
    puts ("The Number of Day in the Year of the provided Date is: #{$Manual_offset}")
    $log.info('ret_date') {"The Number of Day in the Year is: " + $Manual_offset.to_s }
    $log.info('ret_date') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s }
    $log.info('ret_date') {"----- END -----\n\n\n"}
    exit()
end

    # Convert a yday to a date array
def yday_to_date(rawyday)
    rawyday = rawyday.to_i
    check_yday(rawyday)

    days_in_month = {
        "Jan"    =>  31,
        "Feb"    =>  29,
        "Mar"    =>  31,
        "Apr"    =>  30,
        "May"    =>  31,
        "Jun"    =>  30,
        "Jul"    =>  31,
        "Aug"    =>  31,
        "Sep"    =>  30,
        "Oct"    =>  31,
        "Nov"    =>  30,
        "Dec"    =>  31
    }

    if !(Time.now.year % 4 == 0)
        days_in_month[Feb] = 28
    end

    days_in_week = {
        0       =>  "Sun",
        1       =>  "Mon",
        2       =>  "Tues",
        3       =>  "Wed",
        4       =>  "Thurs",
        5       =>  "Fri",
        6       =>  "Sat"
    }

    # days_in_month_array = days_in_month.to_a.flatten!
    # days_in_week_array = days_in_week.to_a.flatten!

    @weekday, @day, @month, @year = "", "", "", Time.now.localtime("-05:00").year.to_s  # Need to account for past years = TODO

    days_in_month.each{|mon_val| # An Array of each Key Value Pair
        puts "mon_val = #{mon_val}\nrawyday = #{rawyday}"
        if (rawyday - mon_val[1] <= 0)
            @month = mon_val[0]
            @day = rawyday
            puts "@month = #{@month}\n@day = #{@day}"
            3.times{ # weeks in a month
                if (rawyday - 7 < 0)
                    @wkdy = Time.new(@year, @month, @day, 5, 1, 1, "-05:00").wday
                    @weekday = days_in_week[@wkdy.to_i]
                end
            }

            break
        else
            rawyday -= mon_val[1]
        end
    }
    date_array = [@year, @month, @weekday, @day]
    return date_array
end

    # Override and resend Question using a Date yyyy-mm-dd instead of a yday
def manDate_to_manOffset(toConvert)
    @cvtDataStr, @data_breakdown_yr, @data_breakdown_mo, @data_breakdown_dy = String.new
    @cvtDataStr = toConvert.to_s
    @data_breakdown_yr = @cvtDataStr[0..3]   # Year
    @data_breakdown_mo = @cvtDataStr[5..6]   # Month
    @data_breakdown_dy = @cvtDataStr[8..9]   # Day
    begin
        if ( @cvtDataStr.size < 10 )
            raise ArgumentError
        end
        $Manual_offset = Time.new(@data_breakdown_yr, @data_breakdown_mo, @data_breakdown_dy).localtime("-05:00").yday
    rescue ArgumentError => err
        puts ("The Provided Date is out of range for a date #{toConvert}. ")
        puts ("Ensure the date follows yyyy-mm-dd eg. 1998-02-25 or 2005-11-08")
        puts (" Exitting...")
        $log.error('manDate_to_manOffset') {"The Provided Date is out of range." + toConvert}
        $log.error('manDate_to_manOffset') {"Information Dump" + err.message + "\n" + err.backtrace.inspect}
        $log.info('manDate_to_manOffset') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s }
        $log.info('manDate_to_manOffset') {"----- END -----\n\n\n"}
        exit()
    end
    $ForceSend = true
    $log.info('manDate_to_manOffset') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s }
end

def cmdline_help
    puts ("""
    Command line options are:
    -------------------------
            fs                  : Force send, regardless of weather or not it was run today or not
                                   <can be combined with other options as well>
            yday?               : No emails are sent, just returns the current number of day in the
                                   year
            yday ###            : Replace ### with an ingeter 1 - 365. Manually sets the day rather
                                   than chosing based on the current date. Good for re-sending old
                                   or missed emails.
            date? yyyy-mm-dd    : No emails are sent. Will return both the yday (see above), and
                                   the question for that day
            date yyyy-mm-dd     : Will send that dates Question email
            parse               : Manully forces the Auto-Parseing of the log file and report any
                                   errors within the last 7 days and email them in the message
            msg                 : Will prompt you to enter a message to append to the question.
                                   you will need to push <CTRL+D> to exit edit mode and send the
                                   emails.
            ds                  : Don't Send, will not acutally send the emails.
                                   Note: This will over ride 'fs' (force send)
            help                : Display this message
            encode file.txt     : Encodes supplied file name from a text file, then exits
            decode file.ebs     : Decodes supplied file name back to a text file, then exits
            no_rs               : This will turn OFF the automatic check and resend of past emails.
            log_level ERROR     : What level to return from the auto_parse_log_file :default is ERROR,
                                   other options are WARN or INFO (which would return the whole file)


    """)
    $log.info('cmdline_help') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s}
    $log.info('cndline_help') {"----- END -----\n\n\n"}
    exit()
end

def add_msg
    puts ("Please enter the message that you would like to append to the question:<ctrl+d to end>")
    @msg = $stdin.read.chomp
    $log.info('add_msg') {"Additional Message to be added: " + @msg}
    return @msg
end

def encode(raw_text_file_name)
    # using base64 encode the txt file and output an encoded file
    enc_fname = raw_text_file_name + ".ebs"
    @i = 0
    while File.exist?(enc_fname)
        @i += 1
        enc_fname = raw_text_file_name + "(" + @i + ").ebs"
    end
    system("touch " + enc_fname)
    encoded_file = File.new(enc_fname, 'w')
    raw_file = File.open(raw_text_file_name, 'r'){|rawline|
        while rline = rawline.gets
            encoded_file.write(Base64.encode64(rline))
        end
    }
    puts ("File #{raw_text_file_name} has been encoded to #{enc_fname}")
    $log.info('encode') {"Encoded " + raw_text_file_name + " to " + enc_fname + ". Completed!"}
    $log.info('encode') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s}
    $log.info('encode') {"----- END -----\n\n\n"}
    exit()
end

def decode(encoded_text_file_name)
    # using base64 decode the txt file and output a text file
    dec_fname = encoded_text_file_name + ".txt"
    @i = 0
    while File.exist?(dec_fname)
        @i += 1
        dec_fname = encoded_text_file_name + "(" + @i + ").txt"
    end
    system("touch " + dec_fname)
    decoded_file = File.open(dec_fname, 'w')
    coded_file = File.open(encoded_text_file_name, 'r'){|codline|
        while cline = codline.gets
            decoded_file.write(Base64.decode64(cline))
        end
    }
    puts ("File #{encoded_text_file_name} has been decoded to #{dec_fname}")
    $log.info('decode') {"Decoded " + encoded_text_file_name + " to " + dec_fname + ". Completed!"}
    $log.info('decode') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s}
    $log.info('decode') {"----- END -----\n\n\n"}
    exit()
end

def find_question(search_offset) # Find the question associated with the provided offset
    found_question = ""
    found_question = $QDAY_DOC_QUESTIONS[search_offset - 1] # Minus 1 because an array starts @ 0 and the year doesn't.

    if ($Add_msg != nil)
        found_question += "\n\n" + $Add_msg
    end

    found_question.each_char{|c|
        begin
            if !(found_question[c].ascii_only?)
                found_question.delete!(c)
            end
            rescue NoMethodError => err
            puts ("The Provided Question contains invalid Characters. ")
            puts ("Today's offset: #{search_offset}")
            puts (" Exitting...")
            $log.error('find_question') {"The Provided contains invalid characters"}
            $log.error('find_question') {"Information Dump" + err.message + "\n" + err.backtrace.inspect}
            $log.info('find_question') {"Command Line Argument(s) was passed. ARGV= " + ARGV.to_s }
            $lof.info('find_question') {"$Add_msg = " + $Add_msg}
            $log.info('find_question') {"----- END -----\n\n\n"}
            exit()
        end
    }
    found_question.force_encoding("UTF-8")

    $log.info('find_question') {"Question that will be sent is : " + found_question }
    $log.info('find_question') {"Provided Offset is : " + search_offset.to_s }
    puts "The Question that will be sent is : #{found_question}\nProvided Offset is : #{search_offset}\n\n"

    return found_question
end

    # Begin Main Program Here.
begin
check_log_date()
$log.level = Logger::INFO            # all msg's from info and up will be logged
$log.datetime_format = "%Y-%m-%d %H:%M:%S "
$log.info('main') {"----- START -----"}

    # Check for required Files and Internet. If it doesn't exist exit program
if !( check_required_files? )
    puts ("Required Files not found!")
    $log.error('check_required_files') { "Required Files - " + DATA_FILE_YAML + " not found!" }
    exit()
end

if !( internet_connection? )
    puts ("      !!!Error No Internet Connection Found!!!")
    puts ("Please Establish an Internet Connection and Re-Run!\n\n")
    $log.error('main') { "No Internet Connection - Unable to open 'http://www.google.com/'"  + "\n----- END -----\n\n\n"}
    exit()
end

    #Load your saved Data form the YAML file and put into 3 objects
$QDAY_DOC_SET, $QDAY_DOC_RECP, $QDAY_DOC_QUESTIONS = YAML.load_file(DATA_FILE_YAML)


$log.info('main') { "Full Arguments list : " + ARGV.to_s }
ARGV.each_index{|a|
          case ARGV[a]
         when "ds"          then $DontSend = true
         when "fs"          then $ForceSend = true
         when "yday?"       then ret_yday
         when "yday"        then check_yday(ARGV[a+1].to_i)
         when "date?"       then ret_date(ARGV[a+1])
         when "date"        then manDate_to_manOffset(ARGV[a+1])
         when "parse"       then $Parse = true
         when "help"        then cmdline_help
         when "--help"      then cmdline_help
         when "msg"         then $Add_msg = add_msg
         when "encode"      then encode(ARGV[a+1])
         when "decode"      then decode(ARGV[a+1])
         when "no_rs"       then $Resend = false
         when "log_level"   then $log_level = ARGV[a+1]
         end }

if ($DontSend); puts("Don't Send has been turned on.\nNo Emails will be Delieverd!!\n"); end

    # (1 .. 500) 500 is the max amount of emails / day you can send with Gmail
recipients_list = Array.new
begin
    $QDAY_DOC_RECP.each_index {|i|; recipients_list << $QDAY_DOC_RECP[i] }
    rescue ArgumentError => recipients_list_err
    $log.error('main') { "Recipients_list error rescue : " + recipients_list_err.message }
end
recipients_list.uniq!
full_recipients_list =  ""
recipients_list.delete(nil)
recipients_list.each_index {|i|
    if ( recipients_list[i] == nil )
        next
    end
    # full_recipients_list is used to format the call to the send_emails method only
    full_recipients_list += '"' + recipients_list[i] + '"' + ", " }
$log.info('main') { "Full recipients list : " + full_recipients_list }

    # days offset is to start at the right spot of the list & to check if it's been run today
if !($Manual_offset.to_i > 0)
    days_offset = Time.now.localtime("-05:00").yday
    $log.info('main') { "Current offset is : " + days_offset.to_s }
else
    days_offset = $Manual_offset.to_i
    $log.info('main') { "Current offset is Manually Set at : " + days_offset.to_s }
end


    # Determine if it's been run today or not
store_pos = DATA.pos
f = File.new($0,'r+')
data_store = []
DATA.each {|line|
    if ( line == "" || line == "\n" )
        next
    end
    data_store << line.chomp!
          }
data_store.uniq!

    # Perform a check to see if the program was completed yesterday or not and resend the emails if not.
if ( ($Resend == true) || (data_store[0].to_i + 1 != days_offset.to_i) || (data_store[1] == false) )
    if ( days_offset.to_i - data_store[0].to_i > 1 ) # Find out how many days we need to make up for
        days_to_resend = days_offset.to_i - data_store[0].to_i
    end
    diff = days_to_resend.to_i
    puts ("The total amount of days to resend : #{diff}")
    diff.downto(2){
        resend_yday = days_offset.to_i - days_to_resend.to_i + 1
        todays_question = find_question(resend_yday)    # This might need to be (days_offset - days_to_resend + 1)
        resend_date = yday_to_date(resend_yday)         # This is date_array = [0 -> @year, 1 -> @month, 2 -> @weekday, 3 -> @day]
        resend_date_str = "\nThis is a ReSend for : " + resend_date[2].to_s + " " + resend_date[1].to_s + " " +
            resend_date[3].to_s + " " + resend_date[0].to_s
        todays_question += resend_date_str
        if !($DontSend); send_emails(QDAY_DOC_SET, full_recipients_list, "Question of the day -RESEND-", todays_question); end
        puts ("#{resend_date_str}")
        puts ("#{recipients_list.length} Emails sent.\n" + "-" * $padding)
        $log.warn('main - resend_check') {"Current offset : " + resend_yday.to_s}
        $log.warn("main - resend_check") {"Resend Msg : " + todays_question}
        $log.warn("main - resend_check") {resend_date_str[1 ... resend_date_str.size]}
        days_to_resend = days_to_resend.to_i - 1
    }
end

    # Send Emails ..
if ($Manual_offset = 0 && !$ForceSend )
    if ( data_store[0] != days_offset.to_s )
        todays_question = find_question(days_offset)
        if !($DontSend); send_emails($QDAY_DOC_SET, full_recipients_list, "", todays_question); end
        puts("#{recipients_list.length} Emails sent.\n" + "-" * $padding)
        $log.info('send_emails') { recipients_list.length.to_s + " Emails sent" }
        $IsCompleted = true
    else
        puts ("\nEmails have already been sent today!")
        puts ("0 Emails have been sent\n\n\n" + "-" * $padding)
        $log.warn('send_emails') { "0 Emails sent. Already ran today.\n\n The Current Offset equals the stored offset. \n ie: Program was already ran today.\n 0 Emails sent.\n Stored offset  : " + data_store[0] + "\n Current offset : " + days_offset.to_s + "\n" }
        $IsCompleted = true
    end
else
    if ($ForceSend)
        todays_question = find_question(days_offset)
        if !($DontSend); send_emails($QDAY_DOC_SET, full_recipients_list, "", todays_question); end
        puts ("#{recipients_list.length} Emails Force_sent.\n" + "-" * $padding)
        $log.info('send_emails - ForceSend') { recipients_list.length.to_s + " Emails Force_sent" }
        $IsCompleted = true
    else
        todays_question = find_question(days_offset)
        if !($DontSend); send_emails($QDAY_DOC_SET, full_recipients_list, "", todays_question); end
        puts ("#{recipients_list.length} Emails sent from Manual_offset.\n" + "-" * $padding)
        $log.info('send_emails - Manual_offset') { recipients_list.length.to_s + " Emails sent from Manual_offset" }
        $IsCompleted = true
    end
end

$log.info('main') {"----- END -----\n\n\n"}
$log.close

    # Determine if to parse the Log file or not
if ( Time.now.localtime("-05:00").friday? || $Parse == true || Time.now.localtime("-05:00").day.to_i >= 28)
    error_log_message = String.new
    error_log_message = auto_parse_log_file($Log_file)
    if !(error_log_message.nil?)
        send_emails($QDAY_DOC_SET, "ben.spiessens@live.ca","Qday ---ERROR LOG---", error_log_message)
        puts ("""
        Is it Friday = #{Time.now.localtime("-05:00").friday?}
        Was the parse command line argument passed = #{$Parse}
        Is the current day over 28 (end of month in the mid week) = #{Time.now.localtime("-05:00").day.to_i >= 28}

        #{error_log_message}
        """)
        puts ("Error Log Email sent.")
    end
end

f.seek(store_pos)
f.write(days_offset.to_s + "\n")
f.write($IsCompleted.to_s + "  ")

    # Below the __end__ is the last ran days_offset value to compare
    # if it's been run today or not
end
__END__
132
true    
