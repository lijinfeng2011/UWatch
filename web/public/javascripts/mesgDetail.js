    var myScroll,
        pullDownEl, pullDownOffset,
        pullUpEl, pullUpOffset,
        generatedCount = 0;

    var $filterRow;

    function pullDownAction( data ) {
        var $mesgList = $('#contentList1');
        setTimeout( function () {
            var content = '', 
                count = 0;
            $.each( data.response, function( n, mesg ) {
                count++;
                content = content + '<li data-swipeurl="#"><span class="index hide">';
                content = content + mesg.idx;
                content = content + '</span><span class="node hide">';
                content = content + mesg.node;
                content = content + '</span>';
                content = content + mesg.content;
                content = content + '</li>';
            });

           // if ( count > 0 ) {
                $mesgList.find('li').removeClass('gary').addClass('gary');
                var number = parseInt($('.listHeader').find('.count').text()) + count;
                $('.listHeader').find('.count').text(number);
           // }
           
            $mesgList.prepend(content).listview('refresh');
            myScroll.refresh();

            bindSwipeEvent( $('#contentList1 li') );
            
        }, 100);
    }


    function pullUpAction ( data ) {
        setTimeout( function () {
            var content = '', 
                count = 0;
            $.each( data.response, function( n, mesg ) {
                count++;
                content = content + '<li class="gary"> <span class="index hide">';
                content = content + mesg.idx;
                content = content + '</span><span class="node hide">';
                content = content + mesg.node;
                content = content + '</span>';
                content = content + mesg.content;
                content = content + '</li>';
            });

            if ( count > 0 ) {
                var number = parseInt($('.listHeader').find('.count').text()) + count;
                $('.listHeader').find('.count').text(number);
            }

            $("#contentList1").append(content).listview('refresh');
            myScroll.refresh();
	
        }, 100);
    }


    function loaded2() {
        if( myScroll!=null ) { myScroll.destroy(); }

        pullDownEl = document.getElementById('pullDown');
        pullDownOffset = pullDownEl.offsetHeight;
        pullUpEl = document.getElementById('pullUp');	
        pullUpOffset = pullUpEl.offsetHeight;
			
        myScroll = new iScroll('wrapperContent1', {
            scrollbarClass: 'myScrollbar', 
            useTransition: false, 
            topOffset: pullDownOffset,
            onRefresh: function () {
                if (pullDownEl.className.match('loading')) {
                    pullDownEl.className = '';
                    pullDownEl.querySelector('.pullDownLabel').innerHTML = '下拉获取最新数据...';
                } else if (pullUpEl.className.match('loading')) {
                    pullUpEl.className = '';
                    pullUpEl.querySelector('.pullUpLabel').innerHTML = '上拉获取历史数据...';
                }
            },
            onScrollMove: function () {
                if (this.y > 5 && !pullDownEl.className.match('flip') && !$('#cancelBtn').attr('disabled')) {
                    pullDownEl.className = 'flip';
                    pullDownEl.querySelector('.pullDownLabel').innerHTML = '松手开始更新...';
                    this.minScrollY = 0;
                } else if (this.y < 5 && pullDownEl.className.match('flip')) {
                    pullDownEl.className = '';
                    pullDownEl.querySelector('.pullDownLabel').innerHTML = '下拉获取最新数据...';
                    this.minScrollY = -pullDownOffset;
                } else if (this.y < (this.maxScrollY - 5) && !pullUpEl.className.match('flip')) {
                    pullUpEl.className = 'flip';
                    pullUpEl.querySelector('.pullUpLabel').innerHTML = '松手开始更新...';
                    this.maxScrollY = this.maxScrollY;
                } else if (this.y > (this.maxScrollY + 5) && pullUpEl.className.match('flip')) {
                    pullUpEl.className = '';
                    pullUpEl.querySelector('.pullUpLabel').innerHTML = '上拉获取历史数据...';
                    this.maxScrollY = pullUpOffset;
                }
            },
            onScrollEnd: function () {
                if (pullDownEl.className.match('flip')) {
                    pullDownEl.className = 'loading';
                    pullDownEl.querySelector('.pullDownLabel').innerHTML = '加载中...';	

                    var ajaxOpt = {
                        url: '/ajaxGetMessage?type=new&id=' + $('.hermesName').text(),
                        before: function(){},
                        success: pullDownAction,
                        complete: function(){},
                        error: function(){}
                    };

                    unbindSwipeEvent( $('#contentList1 li') );
                    sendAjaxRequest( ajaxOpt );
                } else if (pullUpEl.className.match('flip')) {
                    pullUpEl.className = 'loading';
                    pullUpEl.querySelector('.pullUpLabel').innerHTML = '加载中...';
                    
                    var last = $("#contentList1>li:last").find('.index').text();
                    var ajaxOpt = {
                        url: '/ajaxGetMessage?type=old&id='+$('.hermesName').text()+'&pos='+last,
                        before: function(){},
                        success: pullUpAction,
                        complete: function(){},
                        error: function(){}
                    };

                    sendAjaxRequest( ajaxOpt );
                }
            }
        });

        setTimeout(function () { document.getElementById('wrapperContent1').style.left = '0'; }, 800);
    }

    $(document).on('pagebeforeshow', '#mesgDetail', function() {
        setTimeout(loaded2, 1000); 
        if (sessionStorage.getItem('glanceView') == 'oncall') {
            $('#cancelBtn').attr('disabled', 'true');
        }
    });

    $(document).ready(function() {
        bindSwipeEvent( $('#contentList1 li') );
    });

    function unbindSwipeEvent( el ) {
        el.filter('[data-swipeurl]').each(function(i, el){ 
            $(el).off('swipe');
        });
    }

    function bindSwipeEvent( el ) {
        el.swipeDelete({
            btnTheme: 'b',
            btnLabel: '屏蔽1小时',
            btnClass: 'aSwipeButton',
            click: function(e) {
                e.preventDefault();
                $filterRow = $(e.target).closest('li');
                var node = $filterRow.find('.node').text();
                var name = $('.hermesName').text(); 
                var ajaxOpt = {
                    url: '/ajaxSetFilterMessage?name=' + name + '&node=' + node,
                    before: function(){},
                    complete: function(){},
                    error: function(){},
                    success: updateFilter };

                sendAjaxRequest( ajaxOpt );
            }
        });
    }

    function updateFilter( data ) {
        if ( data.response == 0 && $filterRow) {
            $filterRow.removeClass('green').addClass('green');
        }

        $filterRow = null;    
    }

    function cancelSub( hermes ) {
        var tmp = hermes.split(/\./);
        if (tmp.length < 2) { return;}
 
        var hms = tmp[0];
        var item = hermes.substring(hms.length+1, hermes.length);
        var ajaxOpt = {
                url: '/ajaxBookSubscribe?hermesID=' + hms + '&' + item + '=0',
                before: showLoader,
                success: responseCancel,
                complete: hideLoader,
                error: ajax_error
            };

            sendAjaxRequest( ajaxOpt );
    }

    function responseCancel(data) {
       if ( data.response === 1 ) { 
           popOver('Sorry，稍后再试下嘛！'); 
       } else if ( data.response === 0 || data.response === 3 ) { 
           $('#contentList1').find('li').removeClass('gary').addClass('gary');
           $('#cancelBtn').attr('disabled', 'true').text('取消成功');
           popOver('取消订阅成功了yeah～'); 
       } 
    }
