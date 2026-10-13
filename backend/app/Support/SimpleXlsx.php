<?php

namespace App\Support;

use RuntimeException;
use ZipArchive;

class SimpleXlsx
{
    /**
     * @return list<list<string>>
     */
    public static function readRows(string $path): array
    {
        $zip = new ZipArchive();
        if ($zip->open($path) !== true) {
            throw new RuntimeException('Unable to read the Excel file.');
        }

        $shared = self::sharedStrings($zip->getFromName('xl/sharedStrings.xml') ?: '');
        $sheet = $zip->getFromName('xl/worksheets/sheet1.xml') ?: '';
        $zip->close();

        if ($sheet === '') {
            throw new RuntimeException('The Excel file has no sheet.');
        }

        $xml = simplexml_load_string($sheet);
        if ($xml === false) {
            throw new RuntimeException('The Excel sheet is invalid.');
        }

        $xml->registerXPathNamespace('m', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main');
        $rows = [];

        foreach ($xml->xpath('//m:sheetData/m:row') ?: [] as $row) {
            $line = [];
            $col = 0;
            foreach ($row->children('http://schemas.openxmlformats.org/spreadsheetml/2006/main')->c as $cell) {
                $index = self::columnIndex((string) $cell['r']);
                while ($col < $index) {
                    $line[] = '';
                    $col++;
                }
                $line[] = self::cellValue($cell, $shared);
                $col++;
            }
            $rows[] = $line;
        }

        return $rows;
    }

    /**
     * @param  list<list<string|int|float|null>>  $rows
     */
    public static function binary(array $rows): string
    {
        $sheet = self::sheetXml($rows);
        $files = [
            '[Content_Types].xml' => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                .'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                .'<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                .'<Default Extension="xml" ContentType="application/xml"/>'
                .'<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
                .'<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
                .'</Types>',
            '_rels/.rels' => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                .'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                .'<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
                .'</Relationships>',
            'xl/workbook.xml' => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                .'<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
                .'<sheets><sheet name="Products" sheetId="1" r:id="rId1"/></sheets></workbook>',
            'xl/_rels/workbook.xml.rels' => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                .'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                .'<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
                .'</Relationships>',
            'xl/worksheets/sheet1.xml' => $sheet,
        ];

        $tmp = tempnam(sys_get_temp_dir(), 'xlsx');
        if ($tmp === false) {
            throw new RuntimeException('Unable to create the Excel file.');
        }
        @unlink($tmp);

        $zip = new ZipArchive();
        if ($zip->open($tmp, ZipArchive::CREATE) !== true) {
            throw new RuntimeException('Unable to create the Excel file.');
        }

        foreach ($files as $name => $contents) {
            $zip->addFromString($name, $contents);
        }
        $zip->close();

        $binary = file_get_contents($tmp);
        @unlink($tmp);

        if ($binary === false) {
            throw new RuntimeException('Unable to create the Excel file.');
        }

        return $binary;
    }

    /**
     * @return list<string>
     */
    private static function sharedStrings(string $xml): array
    {
        if ($xml === '') {
            return [];
        }

        $doc = simplexml_load_string($xml);
        if ($doc === false) {
            return [];
        }

        $shared = [];
        $doc->registerXPathNamespace('m', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main');
        foreach ($doc->xpath('//m:si') ?: [] as $item) {
            $text = '';
            foreach ($item->xpath('.//m:t') ?: [] as $node) {
                $text .= (string) $node;
            }
            $shared[] = $text;
        }

        return $shared;
    }

    /**
     * @param  list<string>  $shared
     */
    private static function cellValue(\SimpleXMLElement $cell, array $shared): string
    {
        $nodes = $cell->children('http://schemas.openxmlformats.org/spreadsheetml/2006/main');
        if (isset($nodes->is)) {
            $text = '';
            foreach ($nodes->is->t as $node) {
                $text .= (string) $node;
            }
            if ($text === '' && isset($nodes->is->r)) {
                foreach ($nodes->is->r as $run) {
                    $text .= (string) $run->t;
                }
            }

            return $text;
        }

        $type = (string) $cell->attributes()->t;
        if ($type === 's') {
            return $shared[(int) $nodes->v] ?? '';
        }

        return (string) $nodes->v;
    }

    private static function columnIndex(string $ref): int
    {
        $letters = preg_replace('/[^A-Z]/', '', strtoupper($ref)) ?: 'A';
        $index = 0;
        foreach (str_split($letters) as $letter) {
            $index = ($index * 26) + (ord($letter) - 64);
        }

        return max(0, $index - 1);
    }

    /**
     * @param  list<list<string|int|float|null>>  $rows
     */
    private static function sheetXml(array $rows): string
    {
        $body = '';
        foreach ($rows as $r => $row) {
            $cells = '';
            foreach (array_values($row) as $c => $value) {
                $ref = self::columnName($c).($r + 1);
                $text = htmlspecialchars((string) ($value ?? ''), ENT_XML1 | ENT_QUOTES, 'UTF-8');
                $cells .= '<c r="'.$ref.'" t="inlineStr"><is><t>'.$text.'</t></is></c>';
            }
            $body .= '<row r="'.($r + 1).'">'.$cells.'</row>';
        }

        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            .'<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            .'<sheetData>'.$body.'</sheetData></worksheet>';
    }

    private static function columnName(int $index): string
    {
        $name = '';
        $n = $index + 1;
        while ($n > 0) {
            $n--;
            $name = chr(65 + ($n % 26)).$name;
            $n = intdiv($n, 26);
        }

        return $name;
    }
}
