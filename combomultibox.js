$.widget( 'custom.combomultibox',
  {
  _create: function()
    {
    this.wrapper = $( '<span>' )
      .addClass( 'custom-combobox' )
      .insertAfter( this.element );
 
    this.element.hide();
    this._createAutocomplete();
    },

  _createOption: function(opt,before)
    {
    if(before==undefined)
      {
      this.wrapper.append($('<span>').html(opt.text).append($('<input type="checkbox" checked="1"/>').click(opt,this._unselectOption)));
      }
    else
      {
      $('<span>').html(opt.text).append($('<input type="checkbox" checked="1"/>').click(opt,this._unselectOption)).insertBefore(before);
      }
    },

  _createAutocomplete: function()
    {
    var selected = this.element.children( ':selected' );
    var i;
    var origthis=this;
    for(i=0;i<selected.length;i++)
      {
      this._createOption(selected[i]);
      }
 
    this.input = $( '<input>' )
      .appendTo( this.wrapper )
      .attr( 'title', '' )
      .addClass( 'custom-combobox-input ui-widget ui-widget-content ui-state-default ui-corner-left' )
      .keydown(function(event)
        {
        if((event.which==13)||(event.which==9)||(event.which==188))
          {
          var value = origthis.input.val(),
            valueLowerCase = value.toLowerCase(),
            valid = false;
          if(value!='')
            {
            event.preventDefault();
            origthis.input.autocomplete( 'instance' ).close();
            if(event.which==9)
              {
              var bestmatch=false;
              var count=0;
              origthis.element.children( 'option' ).each(function()
                {
                if($( this ).text().toLowerCase().substring(0,valueLowerCase.length) === valueLowerCase)
                  {
                  count++;
                  bestmatch=$( this ).text();
                  }
                });
              if(count==1)
                {
                value=bestmatch;
                valueLowerCase = value.toLowerCase();
                }
              }
            // Search for a match (case-insensitive)
            origthis.element.children( 'option' ).each(function()
              {
              if ( $( this ).text().toLowerCase() === valueLowerCase )
                {
                valid=this;
                return false;
                }
              });

            // Found a match, nothing to do
            if ( valid )
              {
              if(!valid.selected)
                {
                valid.selected = true;
                origthis._createOption(valid,origthis.input);
                }
              origthis.input.val( '' );
              origthis.input.autocomplete( 'instance' ).term = '';
              return;
              }

            // Add new value
            if(origthis.options.autocreate)
              {
              valid=$('<option>',{ value: value });
              valid.selected=true;
              valid.prop('selected',true);
              valid.text=value;
              origthis.element.append(valid);
              origthis._createOption(valid,origthis.input);
              origthis.input.val( '' );
              origthis.input.autocomplete( 'instance' ).term = '';
              }
            else
              {
              origthis.input.val( "" )
                .attr( "title", value + " didn't match any item" )
                .tooltip( "open" );
              origthis.element.val( "" );
              origthis._delay(function()
                {
                origthis.input.tooltip( "close" ).attr( "title", "" );
                }, 2500 );
              origthis.input.autocomplete( "instance" ).term = "";
              }
            }
          }
        })
      .keyup(function(event)
        {
        if((event.which==13)||(event.which==9))
          {
          this.focus();
          }
        })
      .autocomplete(
        {
        delay: 0,
        minLength: 0,
        source: $.proxy( this, '_source' ),
        select: function(event,ui)
          {
          if(!ui.item.option.selected)
            {
            ui.item.option.selected = true;
            origthis._createOption(ui.item.option,this);
            }
          this.value='';
          event.preventDefault();
          }
        })
      .tooltip(
        {
        tooltipClass: 'ui-state-highlight'
        });
 
    this._on( this.input,
      {
//          autocompleteselect: function( event, ui ) {
//            ui.item.option.selected = true;
//            this._trigger( 'select', event, {
//              item: ui.item.option
//            });
//          },
// 
      autocompletechange: '_removeIfInvalid'
      });
    },
 
  _unselectOption: function(event,ui)
    {
    if(event.data.prop)
      {
      event.data.prop('selected',false);
      }
    event.data.selected=false;
    event.target.parentNode.parentNode.removeChild(event.target.parentNode);
    },
 
  _createShowAllButton: function()
    {
    var input = this.input,
      wasOpen = false;
 
    $( '<a>' )
      .attr( 'tabIndex', -1 )
      .attr( 'title', 'Show All Items' )
      .tooltip()
      .appendTo( this.wrapper )
      .button(
        {
        icons:
          {
          primary: 'ui-icon-triangle-1-s'
          },
        text: 'V'
        })
      .removeClass( 'ui-corner-all' )
      .addClass( 'custom-combobox-toggle ui-corner-right' )
      .mousedown(function()
        {
        wasOpen = input.autocomplete( 'widget' ).is( ':visible' );
        })
      .click(function()
        {
        input.focus();
 
        // Close if already visible
        if ( wasOpen )
          {
          return;
          }
 
        // Pass empty string as value to search for, displaying all results
        input.autocomplete( 'search', '' );
        });
    },
 
  _source: function( request, response )
    {
    var matcher = new RegExp( $.ui.autocomplete.escapeRegex(request.term), 'i' );
    var results=this.element.children( 'option' ).map(function()
      {
      var text = $( this ).text();
      if ( this.value && ( !request.term || matcher.test(text) ) )
        return {
          label: text,
          value: text,
          option: this
          };
      });
    response(results.sort(function(a,b)
      {
      var ret;
      ret=(b.value.substring(0,request.term.length).toLowerCase()==request.term.toLowerCase())-
        (a.value.substring(0,request.term.length).toLowerCase()==request.term.toLowerCase());
      return ret;
      }));
    },
 
  _removeIfInvalid: function( event, ui )
    {
    // Selected an item, nothing to do
    if ( ui.item )
      {
      return;
      }
 
    // Search for a match (case-insensitive)
    var value = this.input.val(),
      valueLowerCase = value.toLowerCase(),
      valid = false;
    this.element.children( 'option' ).each(function()
      {
      if ( $( this ).text().toLowerCase() === valueLowerCase )
        {
        valid=this;
        return false;
        }
      });
 
    // Found a match, nothing to do
    if ( valid )
      {
      if(!valid.selected)
        {
        valid.selected = true;
        this._createOption(valid,this.input);
        this.input.val( '' );
        this.input.autocomplete( 'instance' ).term = '';
        }
      return;
      }
 
    // Add new value
    if(this.options.autocreate)
      {
      valid=$('<option>',{ value: value });
      valid.selected=true;
      valid.prop('selected',true);
      valid.text=value;
      this.element.append(valid);
      this._createOption(valid,this.input);
      this.input.val( '' );
      this.input.autocomplete( 'instance' ).term = '';
      }
    else
      {
      this.input.val( "" )
        .attr( "title", value + " didn't match any item" )
        .tooltip( "open" );
      this.element.val( "" );
      this._delay(function()
        {
        this.input.tooltip( "close" ).attr( "title", "" );
        }, 2500 );
      this.input.autocomplete( "instance" ).term = "";
      }
    },
 
  _destroy: function()
    {
    this.wrapper.remove();
    this.element.show();
    }
  });
