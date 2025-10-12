
### New line
{
  "blocks": [
    {
	    "newline": true,
    }
    ]
}

### Transient prompt
{
    "transient_prompt": {
        
        "background": "transparent",
        "foreground": "#ffffff",
      }
}

### Changing color on error
'''json
"foreground_templates": [
    "{{if gt .Code 0}} #ffffff{{end}}"
    "{{if eq .Code 0}} #ffffff{{end}}"
],
'''

or

"foreground": "#ffffff",
"template": "{{ .Shell }}> "
