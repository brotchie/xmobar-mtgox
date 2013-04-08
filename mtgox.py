#!/usr/bin/env python
"""
Pulls the last transacted price from the mtgox bitcoin
exchange. Use with xmobar:

 1. Put mtgox.py in your path;
 2. chmod +x mtgox.py;
 3. Add `Run Com "mtgox.py" [] "mtgox" 600` .xmobarrc commands;
 4. Include %mtgox% in your .xmobarrc template.

Requires the requests Python module:

    sudo pip install requests

"""
import requests

# Add or remove currencies. A full list is available at
# https://bitbucket.org/nitrous/mtgox-api/overview#markdown-header-moneyticker
CURRENCIES = ['USD', 'AUD']

def mtgox_api_ticker(currency):
    try:
        r = requests.get('https://data.mtgox.com/api/2/BTC{}/money/ticker'.format(currency.upper()))
    except requests.exceptions.RequestException, e:
        return None

    data = None
    if r and r.ok:
        json = r.json();
        if json and json.get('result') == 'success':
            data = json.get('data')
    return data

def main():
    rendered = []
    for currency in CURRENCIES:
        data = mtgox_api_ticker(currency)
        rendered.append(data['last']['display_short'] if data else '-')
    print ' '.join(rendered)

if __name__ == '__main__':
    main()
