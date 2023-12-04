#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "esp_log.h"
#include "esp_system.h"
#include "esp_event.h"
#include "esp_timer.h"
#include "nvs_flash.h"
#include "freertos/queue.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "freertos/semphr.h"
#include "freertos/queue.h"
#include "driver/spi_master.h"
#include "driver/gpio.h"


//CMOS控制信号
#define GPIO_BB_MOSI 13
#define GPIO_BB_MISO 12
#define GPIO_BB_SCLK 14
#define GPIO_BB_CS 15

#define GPIO_READY 10	//上升沿中断信号

#define CMOSCTRL_HOST SPI2_HOST

//SPI传输BUF尺寸定义
#define SPI_BB_BUF_SIZE 4  //CMOS控制信号的传输位宽
#define SPI_BB_BUF_SIZE_REV 4


static char cmos_sendbuf[SPI_BB_BUF_SIZE] = {200};
static char cmos_recvbuf[SPI_BB_BUF_SIZE] = {0};
//static uint32_t cmos_sendbuf = 0;
//static uint32_t cmos_recvbuf = 0;

static spi_device_handle_t handle_cmos;

/*CMOS SPI控制参数传输函数*/
static esp_err_t spi_BB_Write(spi_transaction_t t, uint16_t address, uint16_t value){
//package fomat(MSB->LSB): 6bits dummy(zero) + 9bits address + 1bit w/r + 16bits value
	uint32_t packagedata;	//reformatted data
	packagedata = address;	//16bits -> 32bits
	packagedata = (((packagedata << 1) + 1) << 16) + value;

	//push packagedata into send buffer
	cmos_sendbuf[3] |= packagedata>>24;
	cmos_sendbuf[2] |= packagedata>>16;
	cmos_sendbuf[1] |= packagedata>>8;
	cmos_sendbuf[0] |= packagedata;
	//t.length = sizeof(cmos_sendbuf) * 8;
	t.length = sizeof(cmos_sendbuf)*8;
	t.tx_buffer = cmos_sendbuf;
	t.rx_buffer = cmos_recvbuf;

	printf("Size:%d\n",sizeof(cmos_sendbuf)*8);
	printf("Packagedata:%x,%x,%x,%x\n",cmos_sendbuf[3],cmos_sendbuf[2],cmos_sendbuf[1],cmos_sendbuf[0]);

	esp_err_t ret;
	ret = spi_device_transmit(handle_cmos, &t);

	return ret;
}

static void spi_task(void *pvParameters){

	//Configuration for the SPI bus
	spi_bus_config_t buscfg = {
        .mosi_io_num = GPIO_BB_MOSI,
        .miso_io_num = GPIO_BB_MISO,
        .sclk_io_num = GPIO_BB_SCLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1
		//.max_transfer_sz = 81920
    };

	//Configuration for the SPI device on the other side of the bus
	spi_device_interface_config_t devcfg = {
        .command_bits = 0,
        .address_bits = 0,
        .dummy_bits = 0,
        .clock_speed_hz = 20000000, //20MHz时钟频率
		.input_delay_ns = 0,
        .duty_cycle_pos = 128,        //50% duty cycle
		.mode = 1,
        .spics_io_num = GPIO_BB_CS,
        .cs_ena_posttrans = 3,
		.queue_size = 3
    };

	gpio_config_t io_conf = {
		.intr_type = GPIO_INTR_DISABLE,
		.mode = GPIO_MODE_OUTPUT,
		.pull_down_en = 1,
		.pull_up_en = 0,
		.pin_bit_mask = (1 << GPIO_READY)
	};
	gpio_config(&io_conf);

	//注册发送CMOS控制指令的SPI 通道
	static esp_err_t ret_cmos;
	//Initialize the SPI bus and add the device we want to send stuff to.
	ret_cmos = spi_bus_initialize(CMOSCTRL_HOST, &buscfg, SPI_DMA_CH_AUTO);
	assert(ret_cmos==ESP_OK);
	ret_cmos = spi_bus_add_device(CMOSCTRL_HOST, &devcfg, &handle_cmos);
	assert(ret_cmos==ESP_OK);

	esp_err_t ret;

	spi_transaction_t t;

	while(1){

		ESP_ERROR_CHECK(spi_BB_Write(t,0x32A,0x924D));

		gpio_set_level(GPIO_READY,1);	//set ready signal to inform fifo read data out
		vTaskDelay(1 / portTICK_PERIOD_MS);
		
	}
}

//Main application
void app_main(void) {

	xTaskCreatePinnedToCore(spi_task, "spi_task", 8192, NULL, 1, NULL,1);

}
