/*
  ByteBuffer.h - A circular buffer implementation for Arduino
  Created by Sigurdur Orn, July 19, 2010.
 */
#ifndef ByteBuffer_h
#define ByteBuffer_h

#include "WProgram.h"

class ByteBuffer
{
public:
	ByteBuffer();

	void init(unsigned int buf_size);
	
	void clear();
	int getSize();
	int getCapacity();

	int putInFront(byte in);
	int put(byte in);

	byte get();
	byte getFromBack();

	byte peek(unsigned int index);
	
	int putIntInFront(int in);
	int putInt(int in);

	int putLongInFront(long in);
	int putLong(long in);

	int getInt();
	int getIntFromBack();

	long getLong();	
	long getLongFromBack();	

	int putFloatInFront(float in);
	int putFloat(float in);

	float getFloat();	
	float getFloatFromBack();	

private:
	byte* data;

	unsigned int capacity;
	unsigned int position;
	unsigned int length;
};

#endif

