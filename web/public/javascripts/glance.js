( function($) {

    var timer = null;

    $(document).on('pagebeforeshow', "#pageHomepage", function() {
        window.history.replaceState(null, null, '/');
    });

    $(document).on('pagebeforeshow', "#pageSubscribe", function() {
        window.history.replaceState(null, null, '/');
    });

    $(document).on("pagebeforeshow", "#pageGlance", function() {
        window.history.replaceState(null, null, '/');

        $(".message-link").unbind( 'click' )
                          .bind( 'click', getMessageDetail );

        timer = setTimeout( ajaxGetMessageGroup, 10000 );
    });

    $(document).on('pagebeforeshow', "#mesgDetail", function() {
        window.history.replaceState(null, null, '/');
    });

    $(document).on('pagebeforeshow', "#pageLogin", function() {
        window.history.replaceState(null, null, '/');
    });

    $(document).on('pagebeforeshow', "#profile", function() {
        window.history.replaceState(null, null, '/');
    });

    $(document).on("pagebeforehide", "#pageGlance", function() {
        clearTimeout( timer );
    });

    function getMessageDetail ( event ) {
        var $icon = $(event.target).closest('li').find('.status-icon');
        $icon.removeClass('ui-icon-alert')
             .removeClass('ui-icon-info')
             .addClass('ui-icon-check');
    }

    function ajaxGetMessageGroup () {
        $.ajax({
           timeout:   3000,
           async:     true,
           dataType:  "json",
           url:       "/ajaxGetMessageGroup",
           success:   function ( data ) { 
                         // remove already read item;
                         $('.ui-icon-check').closest('li').remove(); 

                         // change data-theme;
                         $('.status-icon').removeClass('ui-icon-alert').addClass('ui-icon-info');

                         if ( data.mesgGrp != null && data.mesgGrp.length > 0 ) {
                            // add new items;
                            $.each (data.mesgGrp, function( n, mesg ) {
                               var $newItem = $('li[name="' + mesg.name + '"]');
                               $newItem.length && $newItem.remove();
                               var newHTML = '<li name="' + mesg.name + '"><a href="/mesgDetail?id=' + mesg.name + '" class="message-link" data-transition="flip">' + mesg.name + '</a><a href="#" class="status-icon" data-icon="alert"></a></li>'; 
                               $('#mainList').prepend(newHTML).listview('refresh');
                            });

                           // bind click function 
                           $(".message-link").unbind( 'click' ).bind( 'click', getMessageDetail );
                           $('.mesg-box').hide(); 
                         } else {
                           var contentHtml = '<p>没有报警信息!</p>'; 
                           $('.mesg-box').html(contentHtml).show();
                         }
                      },
           error:     function( XMLHttpRequest, textStatus, errorThrown ) {
                          var contentHtml = '<p>网络连接失效，无法获取最新信息!</p>';               
                          $('.mesg-box').html(contentHtml).show();
                      },
           complete:  function () {
                          timer = setTimeout( ajaxGetMessageGroup, 20000 );
                      },
        });
    }
})(jQuery);
