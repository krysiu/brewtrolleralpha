/*  
   Copyright (C) 2011 Open Source Control Systems

    This file is part of OpenTroller Framework.

    OpenTroller Framework is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    OpenTroller Framework is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with OpenTroller Framework.  If not, see <http://www.gnu.org/licenses/>.


OpenTroller Framework - Open Source Control System Framework
Software Lead: Matt Reba (matt_AT_brewtroller_DOT_com)
Hardware Lead: Jeremiah Dillingham (jeremiah_AT_brewtroller_DOT_com)

Documentation, Forums and more information available at http://www.oscsys.com
*/



#ifndef OT_LCD_H
	#define OT_LCD_H

	#include <Wire.h>
	#include "OT_LiquidCrystal.h"
	#include <stdlib.h> // for malloc and free
	#include <avr/pgmspace.h>
	#include "OT_Util.h"
	#include <stdint.h>
	#include "OT_Stack.h"

	#define PAD_RIGHT 0
	#define PAD_CENTER 1
	#define PAD_LEFT 2

	namespace OpenTroller {
		class LCD_Generic
		{
			protected:
			uint8_t * _screen;
			uint8_t _cols, _rows, _pos, _custChars[8][8];

			public:
			virtual void init() = 0;
			virtual void update() = 0;
			virtual void setBright(uint8_t) = 0;
			virtual void setContrast(uint8_t) = 0;
			virtual uint8_t getBright() = 0;
			virtual uint8_t getContrast() = 0;

			void begin(uint8_t cols, uint8_t rows);
			void print(const char *sText);
			void write(uint8_t data);
			void setCursor(uint8_t row, uint8_t col);
			void clear();
			void printPad(const char *sText, uint8_t fieldWidth, uint8_t padMode = PAD_LEFT, char pad = ' ');
			void printPad(long value, uint8_t fieldWidth, uint8_t padMode = PAD_LEFT, char pad = ' ', uint8_t base = 10);
			void printPad(unsigned long value, uint8_t fieldWidth, uint8_t padMode = PAD_LEFT, char pad = ' ', uint8_t base = 10);
			void printPad(uint8_t value, uint8_t fieldWidth, uint8_t padMode = PAD_LEFT, char pad = ' ', uint8_t base = 10);
			void printPad(int value, uint8_t fieldWidth, uint8_t padMode = PAD_LEFT, char pad = ' ', uint8_t base = 10);
			void printPad(unsigned int value, uint8_t fieldWidth, uint8_t padMode = PAD_LEFT, char pad = ' ', uint8_t base = 10);
			void print_P(const char *pText);
			void printPad_P(const char *pText, uint8_t fieldWidth, uint8_t padMode = PAD_LEFT, char pad = ' ');
			void printVFloat(unsigned long val, unsigned int divisor, uint8_t fieldWidth);
			void printVFloatPad(unsigned long val, unsigned int divisor, uint8_t fieldWidth, uint8_t padMode = PAD_LEFT, char pad = ' ');
			void setCustChar_P(uint8_t index, const uint8_t *charDef) ;
			void getScreen(uint8_t * retString);
			void getCustChars(uint8_t * retString);
		};

		//*****************************************************************************************************************************
		// 4-Bit GPIO LCD Class
		//*****************************************************************************************************************************

		//**********************************************************************************
		// LCD Timing Fix
		//**********************************************************************************
		// Some LCDs seem to have issues with displaying garbled characters but introducing
		// a delay seems to help or resolve completely. You may comment out the following
		// lines to remove this delay between a print of each character.
		//
		//#define LCD_DELAY_CURSOR 60
		//#define LCD_DELAY_CHAR 60
		//**********************************************************************************

		class LCD4Bit : public LCD_Generic
		{
			private:
			LiquidCrystal * _lcd;

			uint8_t _brightPin, _contrastPin;
			uint8_t _bright, _contrast;
			boolean _bcControl;

			void saveLCDBright(uint8_t val);
			void saveLCDContrast(uint8_t val);
			uint8_t loadLCDBright();
			uint8_t loadLCDContrast();

			public:
			LCD4Bit(uint8_t rs, uint8_t enable, uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7);
			LCD4Bit(uint8_t rs, uint8_t enable, uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7, uint8_t b, uint8_t c);
			void init();
			void update();
			void setBright(uint8_t);
			void setContrast(uint8_t);
			void saveConfig(void);
			uint8_t getBright();
			uint8_t getContrast();
		};




		//*****************************************************************************************************************************
		// I2C LCD Class
		//*****************************************************************************************************************************
		class LCDI2C : public LCD_Generic
		{
			private:
			uint8_t i2cLCDAddr;

			public:
			LCDI2C(uint8_t addr);
			void init();
			void update();
			void setBright(uint8_t);
			void setContrast(uint8_t);
			void saveConfig(void);
			uint8_t getBright();
			uint8_t getContrast();
		};
		
		#if defined OPENTROLLER_LCD4BIT
		  extern OpenTroller::LCD4Bit LCD;
		#elif defined OPENTROLLER_LCDI2C
		  extern OpenTroller::LCDI2C LCD;
		#endif	
	}
#endif