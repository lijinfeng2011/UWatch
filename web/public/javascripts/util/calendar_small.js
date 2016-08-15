function calendar(container_id) {
    var today = new Date();
    this.year = today.getFullYear();
    this.month = today.getMonth();
    this.date = today.getDate();
    this.week_en = new Array('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
    this.month_en = new Array('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');

    this.container = $('#' + container_id);
    this.days = new Array(42);

    this.pMap = {
        'lijinfeng'  :   '#222',
        'jiangwei-s' :   '#ed1c24',
        'wangdahai'  :   '#faa51a',
        'xujinshuai' :   '#0ce3ac', 
        'haoyixin'   :   '#0479a7',
        'zhaosiyu-pd':   '#9c629c',
        'mayunshan'  :   '#6ab5ba',
        'g-cloudops' :   '#1e8c00'
    };

    this.tMap = {
        B: 'Base业务值班',
        S: 'Search业务值班'
    };

    this.pShow = {
        'lijinfeng'  :   1,
        'jiangwei-s' :   1,
        'wangdahai'  :   1,
        'mayunshan'  :   1, 
        'haoyixin'   :   1,
        'zhaosiyu-pd':   1,
        'xujinshuai' :   1,
        'g-cloudops' :   1
    };

    this.countDays = function(year, month) {
         var days_in_months = [31,28,31,30,31,30,31,31,30,31,30,31];
         if (1 == month) return ((0 == year % 4) && (0 != (year % 100))) || (0 == year % 400) ? 29 : 28;
         else return days_in_months[month];
    };

    this.draw = function() {
        this.drawCalendar();
        this.drawDiagram();
        this.drawTasks();
    };

    this.drawTasks = function() {
        var firstDay = new Date(this.year, this.month, 1);
        var start = firstDay.getTime() / 1000 + 1;
        var end = start + this.countDays(this.year, this.month) * 3600 * 24;
        var that = this;

        $.ajax({
            async:       true,
            timeout:     5000,
            type:        'post',  
            url:         '/ajaxGetTasks?s='+start+'&e='+end,
            dataType:    'json',
            contentType: 'application/json',
            beforeSend:  function()     { },
            success:     function(data) { that.printTasks(data.response); },
            complete:    function()     { },  
            error:       function(XMLHttpRequest, textStatus, errorThrown) { 
                             if (textStatus === "timeout") popOver('暂时无法获取值班信息，请稍后再试！'); }
        });
    }

    this.printTasks = function(data) {
        for ( var t in data ) {
            var task = data[t].split(':'),
                begin = parseInt(task[3]),
                last  = parseInt(task[4]);

            var days = begin+last > 24 ? parseInt((begin + last )/24)+1 : 1;

            var $day = null, mesg = '', start='', end='';
            for (var i=0; i<days; i++) {
                var day = parseInt(task[2]) + i;
                $day = $('.date-' + day).closest('.day');
                start = (i == 0) ? begin : 0;
                end = (days == 1)
                      ? begin + last
                      : 24-begin+24*i > last
                          ? last+begin-24*i : 24;

                mesg = task[0]+' ('+start+'点-'+end+'点)';
                $('<div class="task '+task[1]+'" style="background:'+ this.pMap[task[1]] +'">'+mesg+'</div>').appendTo($day);
            } 

        }
       
        this.filter();
    };

    this.fillDays = function() {
        var i = 0, j = 1;
        for (i=0; i<42; i++) { this.days[i] = -1; }

        var firstDay = new Date(this.year, this.month, 1);
        var firstDay_week = firstDay.getDay();
        var totalDays = this.countDays(this.year, this.month);

        for (i=firstDay_week; i<totalDays+firstDay_week; i++) { this.days[i] = j++; }

        var lastDay = firstDay_week + totalDays;
        if (lastDay < 29)      { for(i=28; i<42; i++) { this.days[i] = 0; } }
        else if (lastDay < 36) { for(i=35; i<42; i++) { this.days[i] = 0; } }
    };

    this.drawDiagram = function() {
        var $box = $('<div id="legend" style="margin-top: 1em"></div>'),
            $row = null,
            index = 0;

        var $table = $('<table style="background:#bce774" cellpadding="5" cellspacing="5"></table>');
        $row = $('<tr></tr>').appendTo($table);
        for ( var t in this.tMap ) {
            $('<th>' + t + ':</th>').appendTo($row);
            $('<td style="width:10em">' + this.tMap[t] +'</td>').appendTo($row);   
        }
        $table.appendTo($box);

        index = 0;
        $table = $('<table cellpadding="5" cellspacing="5"></table>');
        for ( var p in this.pMap ) {
            if ( index++%4 == 0 ) { $row = $('<tr></tr>').appendTo($table); }
            var shouldChk = this.pShow[p]==1 ? ' checked="checked"' : '';
            $('<th class="pDiagram"><input type="checkbox"'+shouldChk+' data-role="none" onclick="cal.chkClick(event)" id="'+p+'"></input>'+p+':</th>').appendTo($row);
            $('<td style="width:10em"><div class="diagram" style="background:'+this.pMap[p]+';"></div></td>').appendTo($row);   
        }
        $table.appendTo($box);
        $box.appendTo(this.container);
    };

    this.drawCalendar = function() {
        this.container.empty();        

        this.fillDays();

        var $row = null;
        var $table = $('<table class="mytable" cellpadding="0" cellspacing="0"></table>');
        var $caption = $('<caption></caption>').append($('<span class="year-month">'+this.year + ' '+ this.month_en[this.month]+'</span>'))
                                               .append($('<button style="float:left" data-role="none" onclick="cal.previous()"> Previous </button>'))
                                               .append($('<button style="float:right" data-role="none" onclick="cal.next()"> Next </button>'))
                                               .appendTo($table);
        $row = $('<tr></tr>');       
        for(var i in this.week_en) { $('<th></th>').text(this.week_en[i]).appendTo($row); }
        $row.appendTo($table);

        for (var i in this.days) {
            var d = this.days[i];
            if (0 === d) break;
            if (0 === i%7) { $row = $('<tr></tr>').appendTo($table); }
            if (d < 0) { $('<td class="grayDay"></td>').appendTo($row); }
            else { $('<td><div class="day"><div class="date date-'+d+'">'+d+'</div></div></td>').appendTo($row); }
        }

        $table.appendTo(this.container);
        this._setToday();
    };

    this._setToday = function() {
        var today = new Date();
        var curMonth = today.getFullYear()+' '+this.month_en[today.getMonth()];
        if ($('.year-month').text() == curMonth) {
           $.each ( $('.date'), function(n, item) {
               if ($(item).text() == today.getDate()) {$(item).closest('td').addClass('today');}               
           });
        } 
        
    };

    this.previous = function() {
        if (this.month<=0) { this.month = 11; this.year -=1; }
        else { this.month -= 1; }

        this.draw();
        return false;
    };

    this.next = function() {
        if (this.month>=11) { this.month = 0; this.year +=1; }
        else { this.month += 1; }

        this.draw();
        return false; 
    };

    this.chkClick = function(event) {
        this.pShow[event.target.id] = event.target.checked ? 1 : 0;
        this.filter(); 
    }

    this.filter = function() {
        for (var p in this.pShow) {
            if (this.pShow[p]) { $('.'+p).show(); }
            else { $('.'+p).hide();}
        }
    }
}
